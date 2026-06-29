class_name CrewCommandPanelPlacementPolished
extends CrewCommandPanelPlacementAware


func _ready() -> void:
	super._ready()
	if not _selection.defender_world_clicked.is_connected(
		_on_defender_world_clicked
	):
		_selection.defender_world_clicked.connect(_on_defender_world_clicked)


func request_defender_type(defender_id: int, role_id: int) -> bool:
	if not are_commands_enabled():
		_set_feedback("Команды сейчас недоступны", true)
		return false
	if not CrewRole.is_combat_role(role_id):
		_set_feedback("Неизвестный тип бойца", true)
		return false
	if role_id == CrewRole.Id.SHOOTER and not _crew.is_shooter_role_unlocked():
		_set_feedback("Тип стрелка ещё не открыт", true)
		return false
	var defender: Defender = _crew.get_defender(defender_id)
	if defender == null or not defender.health.is_alive():
		_set_feedback("Боец недоступен", true)
		return false
	var polished_roles := _roles as ShooterCrewRoleManagerPolished
	if polished_roles == null:
		return super.request_defender_type(defender_id, role_id)
	if not polished_roles.set_combat_role(defender_id, role_id):
		_set_feedback("Тип бойца изменить не удалось", true)
		return false
	_selection.select_defender(defender_id)
	_set_feedback(
		"Тип бойца: %s" % (
			"Стрелок" if role_id == CrewRole.Id.SHOOTER else "Боец"
		),
		false
	)
	return true


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


func _on_defender_world_clicked(defender_id: int) -> void:
	_show_defender_command_context(defender_id)


func _show_defender_command_context(defender_id: int) -> void:
	var defender: Defender = _crew.get_defender(defender_id)
	if defender == null or not defender.health.is_alive():
		_close_context()
		return
	_view.rebuild_defender_command_context(
		defender_id,
		_get_combat_role(defender_id),
		_crew.is_shooter_role_unlocked(),
		_build_defender_post_options(defender_id),
		_on_defender_command_type_pressed,
		_on_defender_command_post_pressed,
		_on_defender_command_free_pressed,
		_close_context
	)


func _build_defender_post_options(defender_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot_index: int in range(_slot_specs.size()):
		var spec: Dictionary = _slot_specs[slot_index]
		var kind: int = int(spec["kind"])
		var cell_index: int = int(spec["cell"])
		if (
			kind == SlotKind.FREE_CELL
			and _get_turret_at_cell(cell_index) < 0
		):
			continue
		var description: Dictionary = _describe_slot(spec)
		if not bool(description["available"]):
			continue
		var owner_id: int = int(description["owner"])
		result.append({
			"slot": slot_index,
			"title": String(description["title"]),
			"owner": owner_id,
			"current": owner_id == defender_id,
		})
	return result


func _on_defender_command_type_pressed(
	defender_id: int,
	role_id: int
) -> void:
	if request_defender_type(defender_id, role_id):
		_show_defender_command_context(defender_id)


func _on_defender_command_post_pressed(
	defender_id: int,
	slot_index: int
) -> void:
	if slot_index < 0 or slot_index >= _slot_specs.size():
		_set_feedback("Некорректный пост", true)
		return
	_selection.select_defender(defender_id)
	_on_assign_pressed(slot_index, defender_id)


func _on_defender_command_free_pressed(defender_id: int) -> void:
	if not are_commands_enabled():
		_set_feedback("Команды сейчас недоступны", true)
		return
	var defender: Defender = _crew.get_defender(defender_id)
	if defender == null or not defender.health.is_alive():
		_set_feedback("Боец недоступен", true)
		return
	_selection.select_defender(defender_id)
	_release_post_owner(defender_id)
	_set_feedback("Боец направлен в свободную ячейку", false)
	_close_context()
