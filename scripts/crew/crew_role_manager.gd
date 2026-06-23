class_name CrewRoleManager
extends Node

signal assignment_changed(
	defender_id: int,
	current_role: int,
	target_role: int,
	state: int
)
signal assignment_rejected(defender_id: int, role_id: int, reason: StringName)

const DEFAULT_DYNAMIC_STATION_ID: int = 0

@export_node_path("CrewManager") var crew_manager_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("SteeringInputProvider") var steering_input_path: NodePath
@export_node_path("AnchorSystem") var anchor_system_path: NodePath

var _assignments: Dictionary[int, CrewAssignmentRuntime] = {}
var _stations: RoleStationRegistry = RoleStationRegistry.new()
var _external_action_roles: Dictionary[int, int] = {}
var _initialized: bool = false

@onready var _crew: CrewManager = get_node(crew_manager_path)
@onready var _platform: PlatformController = get_node(platform_path)
@onready var _steering: SteeringInputProvider = get_node(steering_input_path)
@onready var _anchors: AnchorSystem = get_node(anchor_system_path)


func _ready() -> void:
	_crew.defender_spawned.connect(_on_defender_spawned)
	call_deferred("_initialize_assignments")


func _process(_delta: float) -> void:
	if not _initialized:
		return
	for runtime: CrewAssignmentRuntime in _assignments.values():
		if runtime.state != CrewAssignmentRuntime.State.WAITING_FOR_ACTION:
			continue
		if not _is_current_action_active(runtime):
			_begin_transition(runtime)


func request_assignment(
	defender_id: int,
	role_id: int,
	station_id: int = -1
) -> void:
	station_id = _normalize_station_id(role_id, station_id)
	if not _initialized or not _assignments.has(defender_id):
		assignment_rejected.emit(defender_id, role_id, &"unknown_defender")
		return
	if not _is_role_available_in_prototype(role_id, station_id):
		assignment_rejected.emit(defender_id, role_id, &"role_unavailable")
		return

	var runtime: CrewAssignmentRuntime = _assignments[defender_id]
	if runtime.state == CrewAssignmentRuntime.State.DEAD:
		assignment_rejected.emit(defender_id, role_id, &"defender_dead")
		return
	if runtime.state != CrewAssignmentRuntime.State.ACTIVE:
		assignment_rejected.emit(defender_id, role_id, &"defender_busy")
		return
	if (
		runtime.current_role == role_id
		and runtime.current_station_id == station_id
	):
		return
	if not _stations.reserve(role_id, station_id, defender_id):
		assignment_rejected.emit(defender_id, role_id, &"station_occupied")
		return

	runtime.target_role = role_id
	runtime.target_station_id = station_id
	if _is_current_action_active(runtime):
		runtime.state = CrewAssignmentRuntime.State.WAITING_FOR_ACTION
		_emit_assignment(runtime)
		return
	_begin_transition(runtime)


func set_dynamic_role_station(
	role_id: int,
	is_available: bool,
	local_x: float = 0.0,
	station_id: int = DEFAULT_DYNAMIC_STATION_ID,
	relocate_active: bool = false
) -> void:
	station_id = _normalize_station_id(role_id, station_id)
	if is_available:
		var existed: bool = _stations.has_station(role_id, station_id)
		_stations.set_dynamic_target(role_id, station_id, local_x)
		_retarget_moving_assignments(role_id, station_id)
		if existed and relocate_active:
			_relocate_active_assignments(role_id, station_id)
		return
	_disable_dynamic_station(role_id, station_id)
	_stations.clear_dynamic_target(role_id, station_id)


func set_external_role_action_active(
	defender_id: int,
	role_id: int,
	is_active: bool
) -> void:
	if is_active:
		_external_action_roles[defender_id] = role_id
		return
	if _external_action_roles.get(defender_id, -1) == role_id:
		_external_action_roles.erase(defender_id)


func get_assignment(defender_id: int) -> CrewAssignmentRuntime:
	return _assignments.get(defender_id)


func get_role_owner(role_id: int, station_id: int = -1) -> int:
	station_id = _normalize_station_id(role_id, station_id)
	return _stations.get_owner(role_id, station_id)


func get_role_target_x(
	role_id: int,
	defender_id: int = 0,
	station_id: int = -1
) -> float:
	station_id = _normalize_station_id(role_id, station_id)
	return _stations.get_target_x(role_id, station_id, defender_id)


func is_role_station_available(role_id: int, station_id: int = -1) -> bool:
	station_id = _normalize_station_id(role_id, station_id)
	return _stations.has_station(role_id, station_id)


func get_summary() -> String:
	var parts := PackedStringArray()
	var ids: Array[int] = _assignments.keys()
	ids.sort()
	for defender_id: int in ids:
		parts.append(_format_assignment(_assignments[defender_id]))
	return "  ".join(parts)


func _initialize_assignments() -> void:
	_stations.configure(_platform)
	_steering.set_driver_available(false)
	_anchors.set_operator_assigned(AnchorRuntime.Side.LEFT, false)
	_anchors.set_operator_assigned(AnchorRuntime.Side.RIGHT, false)
	for defender: Defender in _crew.get_all_defenders():
		var runtime := CrewAssignmentRuntime.new(defender.defender_id)
		_assignments[defender.defender_id] = runtime
		_connect_defender(defender)

	var initial_roles: Array[int] = [
		CrewRole.Id.DRIVER,
		CrewRole.Id.LEFT_ANCHOR,
		CrewRole.Id.RIGHT_ANCHOR,
	]
	for defender: Defender in _crew.get_all_defenders():
		var role_id: int = CrewRole.Id.FREE_FIGHTER
		if defender.defender_id < initial_roles.size():
			role_id = initial_roles[defender.defender_id]
		_activate_initial_role(defender, role_id)
	_initialized = true


func _activate_initial_role(defender: Defender, role_id: int) -> void:
	var runtime: CrewAssignmentRuntime = _assignments[defender.defender_id]
	runtime.current_role = role_id
	runtime.current_station_id = -1
	runtime.target_role = role_id
	runtime.target_station_id = -1
	runtime.state = CrewAssignmentRuntime.State.ACTIVE
	_stations.reserve(role_id, -1, defender.defender_id)
	defender.teleport_to(
		_stations.get_target_x(role_id, -1, defender.defender_id)
	)
	_activate_capability(role_id)
	_emit_assignment(runtime)


func _activate_replacement(defender: Defender) -> void:
	var runtime: CrewAssignmentRuntime = _assignments.get(defender.defender_id)
	if runtime == null:
		runtime = CrewAssignmentRuntime.new(defender.defender_id)
		_assignments[defender.defender_id] = runtime
	runtime.current_role = CrewRole.Id.FREE_FIGHTER
	runtime.current_station_id = -1
	runtime.target_role = CrewRole.Id.FREE_FIGHTER
	runtime.target_station_id = -1
	runtime.state = CrewAssignmentRuntime.State.ACTIVE
	_emit_assignment(runtime)


func _connect_defender(defender: Defender) -> void:
	defender.destination_reached.connect(_on_defender_destination_reached)
	defender.died.connect(_on_defender_died)


func _begin_transition(runtime: CrewAssignmentRuntime) -> void:
	_deactivate_capability(runtime.current_role)
	var keeps_reservation: bool = (
		runtime.current_role == runtime.target_role
		and runtime.current_station_id == runtime.target_station_id
	)
	if not keeps_reservation:
		_stations.release(
			runtime.current_role,
			runtime.current_station_id,
			runtime.defender_id
		)
	_external_action_roles.erase(runtime.defender_id)
	runtime.current_role = CrewRole.Id.FREE_FIGHTER
	runtime.current_station_id = -1
	runtime.state = CrewAssignmentRuntime.State.MOVING
	var defender: Defender = _crew.get_defender(runtime.defender_id)
	defender.move_to(
		_stations.get_target_x(
			runtime.target_role,
			runtime.target_station_id,
			runtime.defender_id
		)
	)
	_emit_assignment(runtime)


func _activate_target_role(runtime: CrewAssignmentRuntime) -> void:
	runtime.current_role = runtime.target_role
	runtime.current_station_id = runtime.target_station_id
	runtime.state = CrewAssignmentRuntime.State.ACTIVE
	_activate_capability(runtime.current_role)
	_emit_assignment(runtime)


func _is_current_action_active(runtime: CrewAssignmentRuntime) -> bool:
	var defender: Defender = _crew.get_defender(runtime.defender_id)
	if defender != null and defender.is_combat_action_active():
		return true
	match runtime.current_role:
		CrewRole.Id.DRIVER:
			return _steering.is_control_input_active()
		CrewRole.Id.LEFT_ANCHOR:
			return _anchors.is_operator_busy(AnchorRuntime.Side.LEFT)
		CrewRole.Id.RIGHT_ANCHOR:
			return _anchors.is_operator_busy(AnchorRuntime.Side.RIGHT)
		_:
			return (
				_external_action_roles.get(runtime.defender_id, -1)
				== runtime.current_role
			)


func _activate_capability(role_id: int) -> void:
	match role_id:
		CrewRole.Id.DRIVER:
			_steering.set_driver_available(true)
		CrewRole.Id.LEFT_ANCHOR:
			_anchors.set_operator_assigned(AnchorRuntime.Side.LEFT, true)
		CrewRole.Id.RIGHT_ANCHOR:
			_anchors.set_operator_assigned(AnchorRuntime.Side.RIGHT, true)


func _deactivate_capability(role_id: int) -> void:
	match role_id:
		CrewRole.Id.DRIVER:
			_steering.set_driver_available(false)
		CrewRole.Id.LEFT_ANCHOR:
			_anchors.set_operator_assigned(AnchorRuntime.Side.LEFT, false)
		CrewRole.Id.RIGHT_ANCHOR:
			_anchors.set_operator_assigned(AnchorRuntime.Side.RIGHT, false)


func _is_role_available_in_prototype(role_id: int, station_id: int) -> bool:
	if role_id == CrewRole.Id.MEDIC or role_id == CrewRole.Id.TURRET:
		return _stations.has_station(role_id, station_id)
	return (
		role_id == CrewRole.Id.FREE_FIGHTER
		or role_id == CrewRole.Id.DRIVER
		or role_id == CrewRole.Id.LEFT_ANCHOR
		or role_id == CrewRole.Id.RIGHT_ANCHOR
	)


func _retarget_moving_assignments(role_id: int, station_id: int) -> void:
	for runtime: CrewAssignmentRuntime in _assignments.values():
		if (
			runtime.state != CrewAssignmentRuntime.State.MOVING
			or runtime.target_role != role_id
			or runtime.target_station_id != station_id
		):
			continue
		var defender: Defender = _crew.get_defender(runtime.defender_id)
		if defender != null and defender.health.is_alive():
			defender.move_to(
				_stations.get_target_x(role_id, station_id, runtime.defender_id)
			)


func _relocate_active_assignments(role_id: int, station_id: int) -> void:
	for runtime: CrewAssignmentRuntime in _assignments.values():
		if (
			runtime.state != CrewAssignmentRuntime.State.ACTIVE
			or runtime.current_role != role_id
			or runtime.current_station_id != station_id
		):
			continue
		runtime.target_role = role_id
		runtime.target_station_id = station_id
		if _is_current_action_active(runtime):
			runtime.state = CrewAssignmentRuntime.State.WAITING_FOR_ACTION
			_emit_assignment(runtime)
		else:
			_begin_transition(runtime)


func _disable_dynamic_station(role_id: int, station_id: int) -> void:
	for runtime: CrewAssignmentRuntime in _assignments.values():
		var current_match: bool = (
			runtime.current_role == role_id
			and runtime.current_station_id == station_id
		)
		var target_match: bool = (
			runtime.target_role == role_id
			and runtime.target_station_id == station_id
		)
		if not current_match and not target_match:
			continue
		if target_match and not current_match:
			_stations.release(role_id, station_id, runtime.defender_id)
			if runtime.state == CrewAssignmentRuntime.State.MOVING:
				_set_runtime_free(runtime, true)
			else:
				runtime.target_role = runtime.current_role
				runtime.target_station_id = runtime.current_station_id
				runtime.state = CrewAssignmentRuntime.State.ACTIVE
				_emit_assignment(runtime)
			continue
		_deactivate_capability(runtime.current_role)
		_stations.release(
			runtime.current_role,
			runtime.current_station_id,
			runtime.defender_id
		)
		_stations.release(
			runtime.target_role,
			runtime.target_station_id,
			runtime.defender_id
		)
		_external_action_roles.erase(runtime.defender_id)
		_set_runtime_free(runtime, true)


func _set_runtime_free(runtime: CrewAssignmentRuntime, stop_movement: bool) -> void:
	runtime.current_role = CrewRole.Id.FREE_FIGHTER
	runtime.current_station_id = -1
	runtime.target_role = CrewRole.Id.FREE_FIGHTER
	runtime.target_station_id = -1
	if runtime.state != CrewAssignmentRuntime.State.DEAD:
		runtime.state = CrewAssignmentRuntime.State.ACTIVE
		var defender: Defender = _crew.get_defender(runtime.defender_id)
		if stop_movement and defender != null:
			defender.movement.stop()
	_emit_assignment(runtime)


func _normalize_station_id(role_id: int, station_id: int) -> int:
	if role_id == CrewRole.Id.MEDIC:
		return DEFAULT_DYNAMIC_STATION_ID
	if role_id == CrewRole.Id.TURRET:
		return station_id
	return -1


func _format_assignment(runtime: CrewAssignmentRuntime) -> String:
	var current: String = _format_role_station(
		runtime.current_role,
		runtime.current_station_id
	)
	if runtime.state == CrewAssignmentRuntime.State.ACTIVE:
		return "%d:%s" % [runtime.defender_id + 1, current]
	var target: String = _format_role_station(
		runtime.target_role,
		runtime.target_station_id
	)
	var state_name: String = String(
		CrewAssignmentRuntime.State.keys()[runtime.state]
	)
	return "%d:%s>%s(%s)" % [
		runtime.defender_id + 1,
		current,
		target,
		state_name,
	]


func _format_role_station(role_id: int, station_id: int) -> String:
	var result: String = CrewRole.get_display_name(role_id)
	if role_id == CrewRole.Id.TURRET and station_id >= 0:
		result += "#%d" % (station_id + 1)
	return result


func _emit_assignment(runtime: CrewAssignmentRuntime) -> void:
	assignment_changed.emit(
		runtime.defender_id,
		runtime.current_role,
		runtime.target_role,
		runtime.state
	)


func _on_defender_spawned(_defender_id: int, defender: Defender) -> void:
	if not _initialized:
		return
	_connect_defender(defender)
	_activate_replacement(defender)


func _on_defender_destination_reached(defender_id: int) -> void:
	var runtime: CrewAssignmentRuntime = get_assignment(defender_id)
	if runtime == null or runtime.state != CrewAssignmentRuntime.State.MOVING:
		return
	_activate_target_role(runtime)


func _on_defender_died(defender_id: int) -> void:
	var runtime: CrewAssignmentRuntime = get_assignment(defender_id)
	if runtime == null:
		return
	_deactivate_capability(runtime.current_role)
	_stations.release(
		runtime.current_role,
		runtime.current_station_id,
		defender_id
	)
	_stations.release(
		runtime.target_role,
		runtime.target_station_id,
		defender_id
	)
	_external_action_roles.erase(defender_id)
	runtime.state = CrewAssignmentRuntime.State.DEAD
	_emit_assignment(runtime)
