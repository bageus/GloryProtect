class_name PlatformController
extends Node2D

signal driver_assignment_changed(is_assigned: bool)
signal telemetry_changed(position_x: float, velocity_x: float, steering_axis: float)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("WindSystem") var wind_system_path: NodePath

@export_range(8, 32, 1) var cell_count: int = 18
@export_range(16.0, 64.0, 1.0) var cell_width: float = 40.0
@export_range(24.0, 100.0, 1.0) var platform_height: float = 58.0
@export_range(0.0, 500.0, 1.0) var steering_force: float = 178.0
@export_range(0.0, 300.0, 1.0) var linear_drag: float = 36.0
@export_range(20.0, 1000.0, 1.0) var max_horizontal_speed: float = 310.0
@export var world_min_x: float = -2400.0
@export var world_max_x: float = 2400.0
@export var driver_assigned: bool = true

var horizontal_velocity: float = 0.0
var steering_axis: float = 0.0

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _wind_system: WindSystem = get_node(wind_system_path)


func _ready() -> void:
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _game_flow.is_world_simulation_active():
		steering_axis = 0.0
		return

	steering_axis = Input.get_axis(&"ui_left", &"ui_right") if driver_assigned else 0.0

	var steering_acceleration := steering_axis * steering_force
	var total_acceleration := steering_acceleration + _wind_system.get_current_force()

	horizontal_velocity += total_acceleration * delta
	horizontal_velocity = move_toward(horizontal_velocity, 0.0, linear_drag * delta)
	horizontal_velocity = clampf(
		horizontal_velocity,
		-max_horizontal_speed,
		max_horizontal_speed
	)

	var next_x := position.x + horizontal_velocity * delta
	var clamped_x := clampf(next_x, world_min_x, world_max_x)
	if not is_equal_approx(next_x, clamped_x):
		horizontal_velocity = 0.0
	position.x = clamped_x

	telemetry_changed.emit(position.x, horizontal_velocity, steering_axis)


func set_driver_assigned(value: bool) -> void:
	if driver_assigned == value:
		return
	driver_assigned = value
	if not driver_assigned:
		steering_axis = 0.0
	driver_assignment_changed.emit(driver_assigned)
	queue_redraw()


func get_platform_width() -> float:
	return float(cell_count) * cell_width


func _draw() -> void:
	var platform_width := get_platform_width()
	var platform_rect := Rect2(
		Vector2(-platform_width * 0.5, -platform_height * 0.5),
		Vector2(platform_width, platform_height)
	)

	# Placeholder visuals: no external assets are required for the first run.
	draw_rect(platform_rect, Color(0.16, 0.22, 0.31), true)
	draw_rect(platform_rect, Color(0.55, 0.69, 0.82), false, 3.0)

	for index in range(1, cell_count):
		var x := -platform_width * 0.5 + float(index) * cell_width
		draw_line(
			Vector2(x, -platform_height * 0.5),
			Vector2(x, platform_height * 0.5),
			Color(0.28, 0.36, 0.46),
			1.0
		)

	var center_post_rect := Rect2(Vector2(-18.0, -72.0), Vector2(36.0, 72.0))
	draw_rect(center_post_rect, Color(0.26, 0.56, 0.75), true)
	draw_rect(center_post_rect, Color(0.75, 0.91, 1.0), false, 2.0)

	var anchor_post_offset := platform_width * 0.5 - cell_width * 1.5
	for side in [-1.0, 1.0]:
		var post_rect := Rect2(
			Vector2(side * anchor_post_offset - 14.0, -58.0),
			Vector2(28.0, 58.0)
		)
		draw_rect(post_rect, Color(0.55, 0.42, 0.22), true)
		draw_rect(post_rect, Color(0.92, 0.72, 0.35), false, 2.0)

	var orb_color := Color(0.35, 0.9, 1.0) if driver_assigned else Color(0.35, 0.4, 0.45)
	draw_circle(Vector2.ZERO, 17.0, orb_color)
	draw_arc(Vector2.ZERO, 25.0, 0.0, TAU, 48, Color(0.65, 0.96, 1.0), 2.0)
