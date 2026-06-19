class_name AnchorSystem
extends Node2D

signal anchor_state_changed(anchor_id: int, state: AnchorState)
signal anchor_attached(anchor_id: int)
signal anchor_removed(anchor_id: int)
signal anchor_overload_started(anchor_id: int)
signal anchor_broken(anchor_id: int)
signal command_rejected(anchor_id: int, reason: StringName)

enum AnchorSide {
	LEFT,
	RIGHT,
}

enum AnchorState {
	STOWED,
	QUEUED,
	INSTALLING,
	ATTACHED,
	OVERLOADED,
	RETURNING,
}

class AnchorRuntime:
	var anchor_id: int
	var side: AnchorSide
	var state: AnchorState = AnchorState.STOWED
	var operation_progress: float = 0.0
	var overload_progress: float = 0.0


@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("WindSystem") var wind_system_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath

@export var orb_x: float = 0.0
@export var ground_y: float = 510.0
@export_range(40.0, 400.0, 1.0) var installation_zone_half_width: float = 145.0
@export_range(0.1, 10.0, 0.1) var install_duration: float = 1.25
@export_range(0.1, 10.0, 0.1) var overload_duration: float = 2.5
@export_range(0.1, 5.0, 0.1) var return_duration: float = 0.75
@export_range(100.0, 1000.0, 1.0) var rope_length: float = 315.0
@export var left_operator_assigned: bool = true
@export var right_operator_assigned: bool = true

var anchors: Array[AnchorRuntime] = []
var _active_install_id := PackedInt32Array([-1, -1])
var _install_queues: Array = [[], []]
var _remove_all_pending: Array[bool] = [false, false]
var _fully_fixed: bool = false
var _fixed_platform_x: float = 0.0

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _wind: WindSystem = get_node(wind_system_path)
@onready var _platform: PlatformController = get_node(platform_path)


func _ready() -> void:
	process_physics_priority = -20
	_initialize_anchors()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _game_flow.is_world_simulation_active():
		return

	_update_installations(delta)
	_update_returning_anchors(delta)
	_update_overloads(delta)
	_update_full_fix_state()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_1:
			toggle_anchor(0)
		KEY_2:
			toggle_anchor(1)
		KEY_3:
			toggle_anchor(2)
		KEY_4:
			toggle_anchor(3)
		KEY_R:
			request_remove_all()
		_:
			return

	get_viewport().set_input_as_handled()


func toggle_anchor(anchor_id: int) -> void:
	if not _is_valid_anchor_id(anchor_id):
		return

	var anchor := anchors[anchor_id]
	match anchor.state:
		AnchorState.STOWED:
			_request_install(anchor)
		AnchorState.ATTACHED, AnchorState.OVERLOADED:
			_request_remove(anchor)
		_:
			command_rejected.emit(anchor_id, &"anchor_busy")


func request_remove_all() -> void:
	for side in [AnchorSide.LEFT, AnchorSide.RIGHT]:
		_cancel_queued_installs(side)
		if _active_install_id[side] >= 0:
			_remove_all_pending[side] = true
		else:
			_remove_all_on_side(side)


func is_in_installation_zone() -> bool:
	return absf(_platform.position.x - orb_x) <= installation_zone_half_width


func is_fully_fixed() -> bool:
	return _fully_fixed


func get_fixed_platform_x() -> float:
	return _fixed_platform_x


func get_minimum_platform_x() -> float:
	var minimum_x := -INF
	for anchor in anchors:
		if anchor.side != AnchorSide.RIGHT or anchor.state != AnchorState.ATTACHED:
			continue
		var max_horizontal := _get_max_horizontal_rope_distance()
		var ground_x := _get_ground_point(anchor.anchor_id).x
		var local_x := _get_platform_attachment_local_x(anchor.anchor_id)
		minimum_x = maxf(minimum_x, ground_x - max_horizontal - local_x)
	return minimum_x


func get_maximum_platform_x() -> float:
	var maximum_x := INF
	for anchor in anchors:
		if anchor.side != AnchorSide.LEFT or anchor.state != AnchorState.ATTACHED:
			continue
		var max_horizontal := _get_max_horizontal_rope_distance()
		var ground_x := _get_ground_point(anchor.anchor_id).x
		var local_x := _get_platform_attachment_local_x(anchor.anchor_id)
		maximum_x = minf(maximum_x, ground_x + max_horizontal - local_x)
	return maximum_x


func get_state_summary() -> String:
	var parts: PackedStringArray = []
	for anchor in anchors:
		parts.append("%d:%s" % [anchor.anchor_id + 1, AnchorState.keys()[anchor.state]])
	return "  ".join(parts)


func set_operator_assigned(side: AnchorSide, is_assigned: bool) -> void:
	if side == AnchorSide.LEFT:
		left_operator_assigned = is_assigned
	else:
		right_operator_assigned = is_assigned
	if not is_assigned:
		_cancel_queued_installs(side)
	queue_redraw()


func _initialize_anchors() -> void:
	anchors.clear()
	for anchor_id in range(4):
		var runtime := AnchorRuntime.new()
		runtime.anchor_id = anchor_id
		runtime.side = AnchorSide.LEFT if anchor_id < 2 else AnchorSide.RIGHT
		anchors.append(runtime)


func _request_install(anchor: AnchorRuntime) -> void:
	if not is_in_installation_zone():
		command_rejected.emit(anchor.anchor_id, &"outside_installation_zone")
		return
	if not _is_operator_assigned(anchor.side):
		command_rejected.emit(anchor.anchor_id, &"operator_missing")
		return

	var side_index := int(anchor.side)
	if _active_install_id[side_index] >= 0:
		anchor.state = AnchorState.QUEUED
		_install_queues[side_index].append(anchor.anchor_id)
		anchor_state_changed.emit(anchor.anchor_id, anchor.state)
		return

	_start_install(anchor)


func _start_install(anchor: AnchorRuntime) -> void:
	anchor.state = AnchorState.INSTALLING
	anchor.operation_progress = 0.0
	_active_install_id[int(anchor.side)] = anchor.anchor_id
	anchor_state_changed.emit(anchor.anchor_id, anchor.state)


func _request_remove(anchor: AnchorRuntime) -> void:
	if not _is_operator_assigned(anchor.side):
		command_rejected.emit(anchor.anchor_id, &"operator_missing")
		return

	# Removal is immediate in prototype 0.2. A timed removal operation will be
	# introduced together with physical anchor-operator animations.
	_set_anchor_stowed(anchor)
	anchor_removed.emit(anchor.anchor_id)


func _update_installations(delta: float) -> void:
	for side in [AnchorSide.LEFT, AnchorSide.RIGHT]:
		var active_id := _active_install_id[side]
		if active_id < 0:
			continue

		var anchor := anchors[active_id]
		anchor.operation_progress += delta
		if anchor.operation_progress < install_duration:
			continue

		_complete_install(anchor)
		_active_install_id[side] = -1

		if _remove_all_pending[side]:
			_remove_all_pending[side] = false
			_cancel_queued_installs(side)
			_remove_all_on_side(side)
			continue

		_start_next_queued_install(side)


func _complete_install(anchor: AnchorRuntime) -> void:
	anchor.operation_progress = 0.0
	var attachment_position := _get_platform_attachment_world(anchor.anchor_id)
	var ground_position := _get_ground_point(anchor.anchor_id)
	if attachment_position.distance_to(ground_position) > rope_length:
		_start_return(anchor)
		anchor_broken.emit(anchor.anchor_id)
		return

	anchor.state = AnchorState.ATTACHED
	anchor.overload_progress = 0.0
	anchor_state_changed.emit(anchor.anchor_id, anchor.state)
	anchor_attached.emit(anchor.anchor_id)


func _start_next_queued_install(side: AnchorSide) -> void:
	var side_index := int(side)
	while not _install_queues[side_index].is_empty():
		var next_id: int = _install_queues[side_index].pop_front()
		var next_anchor := anchors[next_id]
		if next_anchor.state != AnchorState.QUEUED:
			continue
		if not is_in_installation_zone() or not _is_operator_assigned(side):
			_set_anchor_stowed(next_anchor)
			continue
		_start_install(next_anchor)
		return


func _cancel_queued_installs(side: AnchorSide) -> void:
	var side_index := int(side)
	for queued_id in _install_queues[side_index]:
		var anchor := anchors[int(queued_id)]
		if anchor.state == AnchorState.QUEUED:
			_set_anchor_stowed(anchor)
	_install_queues[side_index].clear()


func _remove_all_on_side(side: AnchorSide) -> void:
	for anchor in anchors:
		if anchor.side != side:
			continue
		if anchor.state == AnchorState.ATTACHED or anchor.state == AnchorState.OVERLOADED:
			_set_anchor_stowed(anchor)
			anchor_removed.emit(anchor.anchor_id)


func _update_overloads(delta: float) -> void:
	for side in [AnchorSide.LEFT, AnchorSide.RIGHT]:
		var holding_anchors := _get_holding_anchors(side)
		if holding_anchors.size() >= 2:
			for anchor in holding_anchors:
				_cancel_overload(anchor)
			continue

		if holding_anchors.is_empty():
			continue

		var anchor: AnchorRuntime = holding_anchors[0]
		if _should_overload(side):
			if anchor.state == AnchorState.ATTACHED:
				anchor.state = AnchorState.OVERLOADED
				anchor.overload_progress = 0.0
				anchor_state_changed.emit(anchor.anchor_id, anchor.state)
				anchor_overload_started.emit(anchor.anchor_id)

			anchor.overload_progress += delta
			if anchor.overload_progress >= overload_duration:
				_start_return(anchor)
				anchor_broken.emit(anchor.anchor_id)
		else:
			_cancel_overload(anchor)


func _cancel_overload(anchor: AnchorRuntime) -> void:
	if anchor.state != AnchorState.OVERLOADED:
		return
	anchor.state = AnchorState.ATTACHED
	anchor.overload_progress = 0.0
	anchor_state_changed.emit(anchor.anchor_id, anchor.state)


func _should_overload(side: AnchorSide) -> bool:
	if _wind.strength_level != 3:
		return false
	if side == AnchorSide.LEFT:
		return _wind.direction > 0
	return _wind.direction < 0


func _start_return(anchor: AnchorRuntime) -> void:
	anchor.state = AnchorState.RETURNING
	anchor.operation_progress = 0.0
	anchor.overload_progress = 0.0
	anchor_state_changed.emit(anchor.anchor_id, anchor.state)


func _update_returning_anchors(delta: float) -> void:
	for anchor in anchors:
		if anchor.state != AnchorState.RETURNING:
			continue
		anchor.operation_progress += delta
		if anchor.operation_progress >= return_duration:
			_set_anchor_stowed(anchor)


func _set_anchor_stowed(anchor: AnchorRuntime) -> void:
	anchor.state = AnchorState.STOWED
	anchor.operation_progress = 0.0
	anchor.overload_progress = 0.0
	anchor_state_changed.emit(anchor.anchor_id, anchor.state)


func _update_full_fix_state() -> void:
	var now_fully_fixed := (
		_count_attached_on_side(AnchorSide.LEFT) > 0
		and _count_attached_on_side(AnchorSide.RIGHT) > 0
	)
	if now_fully_fixed and not _fully_fixed:
		_fixed_platform_x = _platform.position.x
	_fully_fixed = now_fully_fixed


func _count_attached_on_side(side: AnchorSide) -> int:
	var count := 0
	for anchor in anchors:
		if anchor.side == side and anchor.state == AnchorState.ATTACHED:
			count += 1
	return count


func _get_holding_anchors(side: AnchorSide) -> Array[AnchorRuntime]:
	var result: Array[AnchorRuntime] = []
	for anchor in anchors:
		if anchor.side != side:
			continue
		if anchor.state == AnchorState.ATTACHED or anchor.state == AnchorState.OVERLOADED:
			result.append(anchor)
	return result


func _is_operator_assigned(side: AnchorSide) -> bool:
	return left_operator_assigned if side == AnchorSide.LEFT else right_operator_assigned


func _is_valid_anchor_id(anchor_id: int) -> bool:
	return anchor_id >= 0 and anchor_id < anchors.size()


func _get_ground_point(anchor_id: int) -> Vector2:
	var offsets := PackedFloat32Array([-230.0, -125.0, 125.0, 230.0])
	return Vector2(orb_x + offsets[anchor_id], ground_y)


func _get_platform_attachment_local_x(anchor_id: int) -> float:
	var half_width := _platform.get_platform_width() * 0.5
	var inset_outer := 22.0
	var inset_inner := 74.0
	match anchor_id:
		0:
			return -half_width + inset_outer
		1:
			return -half_width + inset_inner
		2:
			return half_width - inset_inner
		3:
			return half_width - inset_outer
		_:
			return 0.0


func _get_platform_attachment_world(anchor_id: int) -> Vector2:
	return Vector2(
		_platform.position.x + _get_platform_attachment_local_x(anchor_id),
		_platform.position.y + _platform.platform_height * 0.45
	)


func _get_max_horizontal_rope_distance() -> float:
	var vertical_distance := absf(
		ground_y - (_platform.position.y + _platform.platform_height * 0.45)
	)
	var squared_horizontal := rope_length * rope_length - vertical_distance * vertical_distance
	return sqrt(maxf(0.0, squared_horizontal))


func _draw() -> void:
	var zone_active := is_in_installation_zone()
	for anchor in anchors:
		var ground_point := _get_ground_point(anchor.anchor_id)
		var platform_point := _get_platform_attachment_world(anchor.anchor_id)

		if anchor.state == AnchorState.ATTACHED or anchor.state == AnchorState.OVERLOADED:
			var rope_color := Color(0.92, 0.75, 0.36)
			if anchor.state == AnchorState.OVERLOADED:
				var flash := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.015)
				rope_color = Color(1.0, 0.12 + flash * 0.25, 0.08)
			draw_line(platform_point, ground_point, rope_color, 4.0)
			draw_circle(ground_point, 10.0, rope_color)
			continue

		if anchor.state == AnchorState.RETURNING:
			var return_ratio := clampf(anchor.operation_progress / return_duration, 0.0, 1.0)
			var returning_point := ground_point.lerp(platform_point, return_ratio)
			draw_circle(returning_point, 9.0, Color(0.85, 0.76, 0.46))
			continue

		if not zone_active:
			continue

		var silhouette_color := Color(0.28, 0.95, 0.48, 0.75)
		if not _is_operator_assigned(anchor.side):
			silhouette_color = Color(0.45, 0.48, 0.52, 0.65)
		elif anchor.state == AnchorState.QUEUED:
			silhouette_color = Color(1.0, 0.78, 0.2, 0.8)
		elif anchor.state == AnchorState.INSTALLING:
			silhouette_color = Color(0.35, 0.78, 1.0, 0.85)

		draw_circle(ground_point, 14.0, silhouette_color)
		draw_line(
			ground_point + Vector2(-9.0, 15.0),
			ground_point + Vector2(9.0, 15.0),
			silhouette_color,
			4.0
		)
