class_name PlatformController
extends Node2D

signal driver_assignment_changed(is_assigned: bool)
signal telemetry_changed(position_x: float, velocity_x: float, steering_axis: float)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("WindSystem") var wind_system_path: NodePath
@export_node_path("SteeringInputProvider") var steering_input_path: NodePath
@export var anchor_system_path: NodePath
@export var balance: PlatformBalance

var horizontal_velocity: float = 0.0
var steering_axis: float = 0.0
var _steering_force_bonus_ratio: float = 0.0
var _release_drag_bonus_ratio: float = 0.0
var _acceleration_bonus_ratio: float = 0.0
var _max_speed_bonus_ratio: float = 0.0
var _sharp_brake_pending: bool = false

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _wind_system: WindSystem = get_node(wind_system_path)
@onready var _steering_input: SteeringInputProvider = get_node(steering_input_path)
@onready var _anchor_system = get_node_or_null(anchor_system_path)


func _ready() -> void:
	assert(balance != null, "PlatformController requires PlatformBalance")
	_steering_input.driver_availability_changed.connect(
		_on_driver_availability_changed
	)


func _physics_process(delta: float) -> void:
	if not _game_flow.is_world_simulation_active():
		steering_axis = 0.0
		return

	steering_axis = _steering_input.get_steering_axis()
	var control_input_active: bool = _steering_input.is_control_input_active()
	if _sharp_brake_pending:
		horizontal_velocity = 0.0
		_sharp_brake_pending = false

	var steering_acceleration := (
		steering_axis
		* get_effective_steering_force()
	)
	var total_acceleration := steering_acceleration + _wind_system.get_current_force()
	horizontal_velocity += total_acceleration * delta
	horizontal_velocity = move_toward(
		horizontal_velocity,
		0.0,
		get_effective_linear_drag(control_input_active) * delta
	)
	horizontal_velocity = clampf(
		horizontal_velocity,
		-get_effective_max_horizontal_speed(),
		get_effective_max_horizontal_speed()
	)

	var next_x := position.x + horizontal_velocity * delta
	var clamped_x := _apply_world_and_anchor_constraints(next_x)
	if not is_equal_approx(next_x, clamped_x):
		horizontal_velocity = 0.0
	position.x = clamped_x

	telemetry_changed.emit(position.x, horizontal_velocity, steering_axis)


func set_driver_assigned(value: bool) -> void:
	_steering_input.set_driver_available(value)


func is_driver_assigned() -> bool:
	return _steering_input.driver_available


func is_driver_control_active() -> bool:
	return _steering_input.is_control_input_active()


func set_anchorless_motion_modifiers(
	steering_force_bonus_ratio: float,
	release_drag_bonus_ratio: float,
	acceleration_bonus_ratio: float,
	max_speed_bonus_ratio: float
) -> void:
	_steering_force_bonus_ratio = maxf(0.0, steering_force_bonus_ratio)
	_release_drag_bonus_ratio = maxf(0.0, release_drag_bonus_ratio)
	_acceleration_bonus_ratio = maxf(0.0, acceleration_bonus_ratio)
	_max_speed_bonus_ratio = maxf(0.0, max_speed_bonus_ratio)


func reset_anchorless_motion_modifiers() -> void:
	set_anchorless_motion_modifiers(0.0, 0.0, 0.0, 0.0)
	_sharp_brake_pending = false


func request_sharp_brake() -> void:
	_sharp_brake_pending = true


func get_effective_steering_force() -> float:
	return balance.steering_force * (
		1.0 + _steering_force_bonus_ratio + _acceleration_bonus_ratio
	)


func get_effective_linear_drag(control_input_active: bool = false) -> float:
	if control_input_active:
		return balance.linear_drag
	return balance.linear_drag * (1.0 + _release_drag_bonus_ratio)


func get_effective_max_horizontal_speed() -> float:
	return balance.max_horizontal_speed * (1.0 + _max_speed_bonus_ratio)


func get_platform_width() -> float:
	return float(balance.cell_count) * balance.cell_width


func get_platform_height() -> float:
	return balance.platform_height


func get_cell_count() -> int:
	return balance.cell_count


func is_valid_cell(cell_index: int) -> bool:
	return cell_index >= 0 and cell_index < balance.cell_count


func get_cell_local_x(cell_index: int) -> float:
	if not is_valid_cell(cell_index):
		return 0.0
	return (
		-get_platform_width() * 0.5
		+ (float(cell_index) + 0.5) * balance.cell_width
	)


func get_nearest_cell_index(local_x: float) -> int:
	var left_edge: float = -get_platform_width() * 0.5
	var raw_index: int = floori((local_x - left_edge) / balance.cell_width)
	return clampi(raw_index, 0, balance.cell_count - 1)


func _apply_world_and_anchor_constraints(next_x: float) -> float:
	var minimum_x := balance.world_min_x
	var maximum_x := balance.world_max_x

	if _anchor_system == null:
		return clampf(next_x, minimum_x, maximum_x)
	if _anchor_system.is_fully_fixed():
		return clampf(
			_anchor_system.get_fixed_platform_x(),
			minimum_x,
			maximum_x
		)

	var anchor_minimum: float = _anchor_system.get_minimum_platform_x()
	var anchor_maximum: float = _anchor_system.get_maximum_platform_x()
	if anchor_minimum != -INF:
		minimum_x = maxf(minimum_x, anchor_minimum)
	if anchor_maximum != INF:
		maximum_x = minf(maximum_x, anchor_maximum)

	return clampf(next_x, minimum_x, maximum_x)


func _on_driver_availability_changed(is_available: bool) -> void:
	if not is_available:
		steering_axis = 0.0
	driver_assignment_changed.emit(is_available)
