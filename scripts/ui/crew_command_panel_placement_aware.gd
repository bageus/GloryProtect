class_name CrewCommandPanelPlacementAware
extends CrewCommandPanelFixed

func _ready() -> void:
	super._ready()
	if not _crew.shooter_upgrades_changed.is_connected(_on_shooter_upgrades_changed):
		_crew.shooter_upgrades_changed.connect(_on_shooter_upgrades_changed)

func _unhandled_input(event: InputEvent) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root != null and scene_root.has_node("BuildablePlacementController"):
		return
	super._unhandled_input(event)

func request_defender_type(defender_id: int, role_id: int) -> bool:
	if not are_commands_enabled():
		_set_feedback("Команды сейчас недоступны", true)
		return false
	if role_id != CrewRole.Id.FREE_FIGHTER and role_id != CrewRole.Id.SHOOTER:
		_set_feedback("Неизвестный тип защитника", true)
		return false
	if role_id == CrewRole.Id.SHOOTER and not _crew.is_shooter_role_unlocked():
		_set_feedback("Тип стрелка ещё не открыт", true)
		return false
	var defender: Defender = _crew.get_defender(defender_id)
	if defender == null or not defender.health.is_alive():
		_set_feedback("Защитник недоступен", true)
		return false
	if not _free_cell_by_defender.has(defender_id):
		_set_feedback("Защитник не находится в свободной ячейке", true)
		return false
	_selection.select_defender(defender_id)
	_pending_free_moves[defender_id] = int(_free_cell_by_defender[defender_id])
	_roles.request_assignment(defender_id, role_id)
	_set_feedback("Тип защитника изменяется", false)
	return true

func _rebuild_context_menu() -> void:
	if _selected_slot < 0 or _selected_slot >= _slot_specs.size():
		_close_context()
		return
	var spec: Dictionary = _slot_specs[_selected_slot]
	var description: Dictionary = _describe_slot(spec)
	var owner_id: int = int(description["owner"])
	var kind: int = int(spec["kind"])
	var cell_index: int = int(spec["cell"])
	if kind == SlotKind.FREE_CELL and _get_turret_at_cell(cell_index) < 0 and owner_id >= 0:
		var assignment: CrewAssignmentRuntime = _roles.get_assignment(owner_id)
		if assignment != null and _is_combat_type_role(assignment.current_role):
			_view.rebuild_defender_type_context(owner_id, assignment.current_role, _crew.is_shooter_role_unlocked(), _on_type_pressed, _close_context)
			return
	var free_ids: Array[int] = _get_available_free_defenders(owner_id)
	_view.rebuild_context(description, free_ids, _selected_slot, _on_release_pressed, _on_assign_pressed, _close_context)

func _on_type_pressed(defender_id: int, role_id: int) -> void:
	request_defender_type(defender_id, role_id)
	_close_context()

func _update_pending_free_moves() -> void:
	var ids: Array = _pending_free_moves.keys()
	for raw_id: Variant in ids:
		var defender_id := int(raw_id)
		var assignment: CrewAssignmentRuntime = _roles.get_assignment(defender_id)
		if assignment != null and _is_combat_type_role(assignment.current_role) and assignment.state == CrewAssignmentRuntime.State.ACTIVE:
			_move_defender_to_free_cell(defender_id, int(_pending_free_moves[defender_id]))
			_pending_free_moves.erase(defender_id)

func _cleanup_free_assignments() -> void:
	var ids: Array = _free_cell_by_defender.keys()
	for raw_id: Variant in ids:
		var defender_id := int(raw_id)
		var defender: Defender = _crew.get_defender(defender_id)
		var assignment: CrewAssignmentRuntime = _roles.get_assignment(defender_id)
		if defender == null or assignment == null or not defender.health.is_alive():
			_forget_free_cell(defender_id)
			continue
		if not _is_combat_type_role(assignment.current_role) and not _is_combat_type_role(assignment.target_role):
			_forget_free_cell(defender_id)

func _get_free_fighter_at_cell(cell_index: int) -> int:
	for raw_id: Variant in _free_cell_by_defender.keys():
		var defender_id := int(raw_id)
		if int(_free_cell_by_defender[defender_id]) != cell_index:
			continue
		var assignment: CrewAssignmentRuntime = _roles.get_assignment(defender_id)
		var defender: Defender = _crew.get_defender(defender_id)
		if assignment != null and defender != null and defender.health.is_alive() and (_is_combat_type_role(assignment.current_role) or _is_combat_type_role(assignment.target_role)):
			return defender_id
	return -1

func _is_combat_type_role(role_id: int) -> bool:
	return role_id == CrewRole.Id.FREE_FIGHTER or role_id == CrewRole.Id.SHOOTER

func _on_shooter_upgrades_changed() -> void:
	if _view.is_context_visible():
		_rebuild_context_menu()
