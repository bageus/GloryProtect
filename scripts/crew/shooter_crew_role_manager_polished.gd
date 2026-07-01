class_name ShooterCrewRoleManagerPolished
extends ShooterCrewRoleManager

const DRIVER_FIRST_CELL_INDEX: int = 10
const DRIVER_SECOND_CELL_INDEX: int = 11


func _process(delta: float) -> void:
	super._process(delta)
	if _initialized:
		_reconcile_living_assignments()


func get_assignment_count() -> int:
	return _assignments.size()


func has_valid_living_assignment(defender_id: int) -> bool:
	var defender: Defender = _crew.get_defender(defender_id)
	var runtime: CrewAssignmentRuntime = get_assignment(defender_id)
	return (
		defender != null
		and defender.health.is_alive()
		and runtime != null
		and runtime.state != CrewAssignmentRuntime.State.DEAD
	)


func _initialize_assignments() -> void:
	_stations.configure(_platform)
	_stations.set_dynamic_target(
		CrewRole.Id.DRIVER,
		-1,
		(
			_platform.get_cell_local_x(DRIVER_FIRST_CELL_INDEX)
			+ _platform.get_cell_local_x(DRIVER_SECOND_CELL_INDEX)
		) * 0.5
	)
	super._initialize_assignments()
	_reconcile_living_assignments()


func request_assignment(
	defender_id: int,
	role_id: int,
	station_id: int = -1
) -> void:
	var runtime: CrewAssignmentRuntime = get_assignment(defender_id)
	if runtime != null and CrewRole.is_combat_role(role_id):
		runtime.combat_role = role_id
	super.request_assignment(defender_id, role_id, station_id)


func set_combat_role(defender_id: int, role_id: int) -> bool:
	if not CrewRole.is_combat_role(role_id):
		return false
	if role_id == CrewRole.Id.SHOOTER and not _crew.is_shooter_role_unlocked():
		return false
	var defender: Defender = _crew.get_defender(defender_id)
	var runtime: CrewAssignmentRuntime = get_assignment(defender_id)
	if defender == null or runtime == null or not defender.health.is_alive():
		return false

	runtime.combat_role = role_id
	if CrewRole.is_combat_role(runtime.current_role):
		runtime.current_role = role_id
	if CrewRole.is_combat_role(runtime.target_role):
		runtime.target_role = role_id
	_emit_assignment(runtime)
	return true


func get_combat_role(defender_id: int) -> int:
	var runtime: CrewAssignmentRuntime = get_assignment(defender_id)
	if runtime == null or not CrewRole.is_combat_role(runtime.combat_role):
		return CrewRole.Id.FREE_FIGHTER
	if (
		runtime.combat_role == CrewRole.Id.SHOOTER
		and not _crew.is_shooter_role_unlocked()
	):
		return CrewRole.Id.FREE_FIGHTER
	return runtime.combat_role


func _activate_initial_role(defender: Defender, role_id: int) -> void:
	var runtime: CrewAssignmentRuntime = _assignments[defender.defender_id]
	runtime.combat_role = CrewRole.Id.FREE_FIGHTER
	super._activate_initial_role(defender, role_id)


func _set_runtime_free(
	runtime: CrewAssignmentRuntime,
	stop_movement: bool
) -> void:
	var combat_role: int = get_combat_role(runtime.defender_id)
	runtime.current_role = combat_role
	runtime.current_station_id = -1
	runtime.target_role = combat_role
	runtime.target_station_id = -1
	if runtime.state != CrewAssignmentRuntime.State.DEAD:
		runtime.state = CrewAssignmentRuntime.State.ACTIVE
		var defender: Defender = _crew.get_defender(runtime.defender_id)
		if stop_movement and defender != null:
			defender.movement.stop()
	_emit_assignment(runtime)


func _activate_replacement(defender: Defender) -> void:
	var runtime: CrewAssignmentRuntime = _assignments.get(defender.defender_id)
	if runtime == null:
		runtime = CrewAssignmentRuntime.new(defender.defender_id)
		_assignments[defender.defender_id] = runtime
	if not CrewRole.is_combat_role(runtime.combat_role):
		runtime.combat_role = CrewRole.Id.FREE_FIGHTER

	if _has_valid_post_target(runtime):
		runtime.current_role = runtime.combat_role
		runtime.current_station_id = -1
		runtime.state = CrewAssignmentRuntime.State.MOVING
		_move_runtime_to_target(defender, runtime)
		return

	_move_spawned_to_combat_position(defender, runtime)


func _connect_defender(defender: Defender) -> void:
	if not defender.destination_reached.is_connected(
		_on_defender_destination_reached
	):
		defender.destination_reached.connect(
			_on_defender_destination_reached
		)
	if not defender.died.is_connected(_on_defender_died):
		defender.died.connect(_on_defender_died)


func _on_defender_spawned(defender_id: int, defender: Defender) -> void:
	if not _initialized:
		call_deferred(
			"_finalize_spawned_defender",
			defender_id,
			defender.get_instance_id()
		)
		return
	_finalize_spawned_defender(defender_id, defender.get_instance_id())


func _finalize_spawned_defender(
	defender_id: int,
	expected_instance_id: int
) -> void:
	if not _initialized:
		call_deferred(
			"_finalize_spawned_defender",
			defender_id,
			expected_instance_id
		)
		return
	var defender: Defender = _crew.get_defender(defender_id)
	if (
		defender == null
		or not defender.health.is_alive()
		or defender.get_instance_id() != expected_instance_id
	):
		return
	_connect_defender(defender)
	var runtime: CrewAssignmentRuntime = get_assignment(defender_id)
	if runtime == null or runtime.state == CrewAssignmentRuntime.State.DEAD:
		_activate_replacement(defender)


func _reconcile_living_assignments() -> void:
	for defender: Defender in _crew.get_living_defenders():
		_connect_defender(defender)
		var runtime: CrewAssignmentRuntime = get_assignment(defender.defender_id)
		if runtime == null or runtime.state == CrewAssignmentRuntime.State.DEAD:
			_activate_replacement(defender)
			continue
		if runtime.state == CrewAssignmentRuntime.State.MOVING:
			_repair_stopped_transition(defender, runtime)


func _repair_stopped_transition(
	defender: Defender,
	runtime: CrewAssignmentRuntime
) -> void:
	if defender.movement.is_moving():
		return
	if CrewRole.is_fixed_station(runtime.target_role):
		if not _has_valid_post_target(runtime):
			_move_spawned_to_combat_position(defender, runtime)
			return
	_move_runtime_to_target(defender, runtime)


func _move_spawned_to_combat_position(
	defender: Defender,
	runtime: CrewAssignmentRuntime
) -> void:
	_stations.release(
		runtime.target_role,
		runtime.target_station_id,
		runtime.defender_id
	)
	var combat_role: int = get_combat_role(runtime.defender_id)
	runtime.current_role = combat_role
	runtime.current_station_id = -1
	runtime.target_role = combat_role
	runtime.target_station_id = -1
	runtime.state = CrewAssignmentRuntime.State.MOVING
	_move_runtime_to_target(defender, runtime)


func _move_runtime_to_target(
	defender: Defender,
	runtime: CrewAssignmentRuntime
) -> void:
	var target_x: float = _stations.get_target_x(
		runtime.target_role,
		runtime.target_station_id,
		runtime.defender_id
	)
	defender.move_to(target_x)
	if (
		runtime.state == CrewAssignmentRuntime.State.MOVING
		and not defender.movement.is_moving()
	):
		_activate_target_role(runtime)
	else:
		_emit_assignment(runtime)


func _on_defender_died(defender_id: int) -> void:
	var runtime: CrewAssignmentRuntime = get_assignment(defender_id)
	if runtime == null:
		return
	_deactivate_capability(runtime.current_role)
	var current_is_target: bool = (
		runtime.current_role == runtime.target_role
		and runtime.current_station_id == runtime.target_station_id
	)
	if not current_is_target:
		_stations.release(
			runtime.current_role,
			runtime.current_station_id,
			defender_id
		)
	_external_action_roles.erase(defender_id)
	if not _has_valid_post_target(runtime):
		runtime.target_role = get_combat_role(defender_id)
		runtime.target_station_id = -1
	runtime.state = CrewAssignmentRuntime.State.DEAD
	_emit_assignment(runtime)


func _has_valid_post_target(runtime: CrewAssignmentRuntime) -> bool:
	return (
		CrewRole.is_fixed_station(runtime.target_role)
		and _stations.has_station(
			runtime.target_role,
			runtime.target_station_id
		)
		and _stations.get_owner(
			runtime.target_role,
			runtime.target_station_id
		) == runtime.defender_id
	)


func _on_shooter_upgrades_changed() -> void:
	if _crew == null or _crew.is_shooter_role_unlocked():
		return
	for runtime: CrewAssignmentRuntime in _assignments.values():
		if runtime.combat_role == CrewRole.Id.SHOOTER:
			runtime.combat_role = CrewRole.Id.FREE_FIGHTER
		if runtime.current_role == CrewRole.Id.SHOOTER:
			_set_runtime_free(runtime, true)
		elif runtime.target_role == CrewRole.Id.SHOOTER:
			runtime.target_role = CrewRole.Id.FREE_FIGHTER
			runtime.target_station_id = -1
			_emit_assignment(runtime)
