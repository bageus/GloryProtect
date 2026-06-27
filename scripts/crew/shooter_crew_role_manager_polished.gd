class_name ShooterCrewRoleManagerPolished
extends ShooterCrewRoleManager


func request_assignment(
	defender_id: int,
	role_id: int,
	station_id: int = -1
) -> void:
	var runtime: CrewAssignmentRuntime = get_assignment(defender_id)
	if runtime != null and CrewRole.is_combat_role(role_id):
		runtime.combat_role = role_id
	super.request_assignment(defender_id, role_id, station_id)


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
		defender.move_to(
			_stations.get_target_x(
				runtime.target_role,
				runtime.target_station_id,
				runtime.defender_id
			)
		)
		_emit_assignment(runtime)
		return

	_set_runtime_free(runtime, true)


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
