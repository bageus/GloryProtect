class_name CrewRoleManager
extends Node

signal assignment_changed(
	defender_id: int,
	current_role: int,
	target_role: int,
	state: int
)
signal assignment_rejected(defender_id: int, role_id: int, reason: StringName)

@export_node_path("CrewManager") var crew_manager_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("SteeringInputProvider") var steering_input_path: NodePath
@export_node_path("AnchorSystem") var anchor_system_path: NodePath

var _assignments: Dictionary = {}
var _stations := RoleStationRegistry.new()
var _initialized: bool = false

@onready var _crew: CrewManager = get_node(crew_manager_path)
@onready var _platform: PlatformController = get_node(platform_path)
@onready var _steering: SteeringInputProvider = get_node(steering_input_path)
@onready var _anchors: AnchorSystem = get_node(anchor_system_path)


func _ready() -> void:
	call_deferred("_initialize_assignments")


func _process(_delta: float) -> void:
	if not _initialized:
		return

	for assignment in _assignments.values():
		var runtime := assignment as CrewAssignmentRuntime
		if runtime.state != CrewAssignmentRuntime.State.WAITING_FOR_ACTION:
			continue
		if not _is_current_action_active(runtime.current_role):
			_begin_transition(runtime)


func request_assignment(defender_id: int, role_id: int) -> void:
	if not _initialized or not _assignments.has(defender_id):
		assignment_rejected.emit(defender_id, role_id, &"unknown_defender")
		return
	if not _is_role_available_in_prototype(role_id):
		assignment_rejected.emit(defender_id, role_id, &"role_unavailable")
		return

	var runtime := _assignments[defender_id] as CrewAssignmentRuntime
	if runtime.state == CrewAssignmentRuntime.State.DEAD:
		assignment_rejected.emit(defender_id, role_id, &"defender_dead")
		return
	if runtime.state != CrewAssignmentRuntime.State.ACTIVE:
		assignment_rejected.emit(defender_id, role_id, &"defender_busy")
		return
	if runtime.current_role == role_id:
		return
	if not _stations.reserve(role_id, defender_id):
		assignment_rejected.emit(defender_id, role_id, &"station_occupied")
		return

	runtime.target_role = role_id
	if _is_current_action_active(runtime.current_role):
		runtime.state = CrewAssignmentRuntime.State.WAITING_FOR_ACTION
		_emit_assignment(runtime)
		return

	_begin_transition(runtime)


func get_assignment(defender_id: int) -> CrewAssignmentRuntime:
	return _assignments.get(defender_id) as CrewAssignmentRuntime


func get_summary() -> String:
	var parts := PackedStringArray()
	var ids := _assignments.keys()
	ids.sort()
	for defender_id in ids:
		parts.append(_format_assignment(_assignments[defender_id]))
	return "  ".join(parts)


func _initialize_assignments() -> void:
	_stations.configure(_platform)
	_steering.set_driver_available(false)
	_anchors.set_operator_assigned(AnchorRuntime.Side.LEFT, false)
	_anchors.set_operator_assigned(AnchorRuntime.Side.RIGHT, false)

	for defender in _crew.get_all_defenders():
		var runtime := CrewAssignmentRuntime.new(defender.defender_id)
		_assignments[defender.defender_id] = runtime
		defender.destination_reached.connect(_on_defender_destination_reached)
		defender.died.connect(_on_defender_died)

	var initial_roles := [
		CrewRole.Id.DRIVER,
		CrewRole.Id.LEFT_ANCHOR,
		CrewRole.Id.RIGHT_ANCHOR,
	]
	for defender in _crew.get_all_defenders():
		var role_id := (
			initial_roles[defender.defender_id]
			if defender.defender_id < initial_roles.size()
			else CrewRole.Id.FREE_FIGHTER
		)
		_activate_initial_role(defender, role_id)

	_initialized = true


func _activate_initial_role(defender: Defender, role_id: int) -> void:
	var runtime := _assignments[defender.defender_id] as CrewAssignmentRuntime
	runtime.current_role = role_id
	runtime.target_role = role_id
	runtime.state = CrewAssignmentRuntime.State.ACTIVE
	_stations.reserve(role_id, defender.defender_id)
	defender.teleport_to(_stations.get_target_x(role_id, defender.defender_id))
	_activate_capability(role_id)
	_emit_assignment(runtime)


func _begin_transition(runtime: CrewAssignmentRuntime) -> void:
	_deactivate_capability(runtime.current_role)
	_stations.release(runtime.current_role, runtime.defender_id)

	runtime.current_role = CrewRole.Id.FREE_FIGHTER
	runtime.state = CrewAssignmentRuntime.State.MOVING
	var defender := _crew.get_defender(runtime.defender_id)
	defender.move_to(_stations.get_target_x(runtime.target_role, runtime.defender_id))
	_emit_assignment(runtime)


func _activate_target_role(runtime: CrewAssignmentRuntime) -> void:
	runtime.current_role = runtime.target_role
	runtime.state = CrewAssignmentRuntime.State.ACTIVE
	_activate_capability(runtime.current_role)
	_emit_assignment(runtime)


func _is_current_action_active(role_id: int) -> bool:
	match role_id:
		CrewRole.Id.DRIVER:
			return _steering.is_control_input_active()
		CrewRole.Id.LEFT_ANCHOR:
			return _anchors.is_operator_busy(AnchorRuntime.Side.LEFT)
		CrewRole.Id.RIGHT_ANCHOR:
			return _anchors.is_operator_busy(AnchorRuntime.Side.RIGHT)
		_:
			return false


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


func _is_role_available_in_prototype(role_id: int) -> bool:
	return (
		role_id == CrewRole.Id.FREE_FIGHTER
		or role_id == CrewRole.Id.DRIVER
		or role_id == CrewRole.Id.LEFT_ANCHOR
		or role_id == CrewRole.Id.RIGHT_ANCHOR
	)


func _format_assignment(runtime: CrewAssignmentRuntime) -> String:
	var current := CrewRole.get_display_name(runtime.current_role)
	if runtime.state == CrewAssignmentRuntime.State.ACTIVE:
		return "%d:%s" % [runtime.defender_id + 1, current]
	var target := CrewRole.get_display_name(runtime.target_role)
	var state_name := CrewAssignmentRuntime.State.keys()[runtime.state]
	return "%d:%s>%s(%s)" % [
		runtime.defender_id + 1,
		current,
		target,
		state_name,
	]


func _emit_assignment(runtime: CrewAssignmentRuntime) -> void:
	assignment_changed.emit(
		runtime.defender_id,
		runtime.current_role,
		runtime.target_role,
		runtime.state
	)


func _on_defender_destination_reached(defender_id: int) -> void:
	var runtime := get_assignment(defender_id)
	if runtime == null or runtime.state != CrewAssignmentRuntime.State.MOVING:
		return
	_activate_target_role(runtime)


func _on_defender_died(defender_id: int) -> void:
	var runtime := get_assignment(defender_id)
	if runtime == null:
		return
	_deactivate_capability(runtime.current_role)
	_stations.release(runtime.current_role, defender_id)
	_stations.release(runtime.target_role, defender_id)
	runtime.state = CrewAssignmentRuntime.State.DEAD
	_emit_assignment(runtime)
