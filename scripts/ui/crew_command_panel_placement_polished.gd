class_name CrewCommandPanelPlacementPolished
extends CrewCommandPanelPlacementAware


func _get_available_free_defenders(excluded_id: int) -> Array[int]:
	var result: Array[int] = []
	for defender: Defender in _crew.get_living_defenders():
		if defender.defender_id == excluded_id:
			continue
		var assignment: CrewAssignmentRuntime = _roles.get_assignment(
			defender.defender_id
		)
		if (
			assignment != null
			and CrewRole.is_combat_role(assignment.current_role)
			and assignment.state == CrewAssignmentRuntime.State.ACTIVE
		):
			result.append(defender.defender_id)
	return result


func _release_post_owner(defender_id: int) -> void:
	var free_cell: int = _find_empty_free_cell()
	if free_cell >= 0:
		_free_cell_by_defender[defender_id] = free_cell
		_pending_free_moves[defender_id] = free_cell
	else:
		_forget_free_cell(defender_id)
	_roles.request_assignment(defender_id, _get_combat_role(defender_id))


func _assign_free_fighter_to_cell(
	defender_id: int,
	cell_index: int
) -> void:
	_free_cell_by_defender[defender_id] = cell_index
	var assignment: CrewAssignmentRuntime = _roles.get_assignment(defender_id)
	if (
		assignment != null
		and CrewRole.is_combat_role(assignment.current_role)
		and assignment.state == CrewAssignmentRuntime.State.ACTIVE
	):
		_move_defender_to_free_cell(defender_id, cell_index)
		return
	_pending_free_moves[defender_id] = cell_index
	_roles.request_assignment(defender_id, _get_combat_role(defender_id))


func _auto_distribute_free_fighters() -> void:
	for defender: Defender in _crew.get_living_defenders():
		if _free_cell_by_defender.has(defender.defender_id):
			continue
		var assignment: CrewAssignmentRuntime = _roles.get_assignment(
			defender.defender_id
		)
		if (
			assignment == null
			or not CrewRole.is_combat_role(assignment.current_role)
			or assignment.state != CrewAssignmentRuntime.State.ACTIVE
		):
			continue
		var cell_index: int = _find_empty_free_cell()
		if cell_index < 0:
			return
		_assign_free_fighter_to_cell(defender.defender_id, cell_index)


func _get_combat_role(defender_id: int) -> int:
	var polished_roles := _roles as ShooterCrewRoleManagerPolished
	if polished_roles != null:
		return polished_roles.get_combat_role(defender_id)
	var assignment: CrewAssignmentRuntime = _roles.get_assignment(defender_id)
	if assignment != null and CrewRole.is_combat_role(assignment.combat_role):
		return assignment.combat_role
	return CrewRole.Id.FREE_FIGHTER
