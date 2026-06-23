class_name CrewCommandPanel
extends Control

const LEFT_ANCHOR_CELL := 1
const LEFT_FREE_CELLS: Array[int] = [2, 3, 4, 5]
const MEDIC_CELL := 7
const DRIVER_CELL := 10
const RIGHT_FREE_CELLS: Array[int] = [12, 13, 14, 15]
const RIGHT_ANCHOR_CELL := 16

enum SlotKind {
	LEFT_ANCHOR,
	FREE_CELL,
	MEDIC,
	DRIVER,
	RIGHT_ANCHOR,
}

var _game_flow: GameFlowController
var _selection: CrewSelectionController
var _crew: CrewManager
var _roles: CrewRoleManager
var _replacements: CrewReplacementController
var _grid: BuildableGrid
var _platform: PlatformController
var _inventory: BuildableInventory
var _buildable_input: BuildableDebugInput
var _configured := false

var _slot_specs: Array[Dictionary] = []
var _free_cell_by_defender: Dictionary = {}
var _pending_free_moves: Dictionary = {}
var _selected_slot := -1
var _view := CrewCommandPanelView.new()


func configure(
	game_flow: GameFlowController,
	selection: CrewSelectionController,
	roles: CrewRoleManager,
	replacements: CrewReplacementController,
	grid: BuildableGrid
) -> void:
	_game_flow = game_flow
	_selection = selection
	_crew = selection.get_crew_manager()
	_roles = roles
	_replacements = replacements
	_grid = grid
	_platform = grid.get_node(grid.platform_path) as PlatformController
	_inventory = grid.get_node(grid.inventory_path) as BuildableInventory
	_buildable_input = grid.get_node_or_null(
		"../../BuildableDebugInput"
	) as BuildableDebugInput
	_configured = true


func _ready() -> void:
	assert(_configured, "CrewCommandPanel must be configured before entering tree")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_slot_specs()
	_view.build(self, 6, 12, _on_slot_pressed)
	_connect_signals()
	call_deferred("_auto_distribute_free_fighters")
	_update_slots()


func _process(_delta: float) -> void:
	visible = (
		_game_flow.state != GameFlowController.RunState.GAME_OVER
		and _game_flow.state != GameFlowController.RunState.CARD_SELECTION
	)
	if not visible:
		return
	_update_pending_free_moves()
	_cleanup_free_assignments()
	_auto_distribute_free_fighters()
	_update_slots()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if not _can_place_turret_with_mouse():
		return
	var local_mouse: Vector2 = _platform.get_local_mouse_position()
	if absf(local_mouse.x) > _platform.get_platform_width() * 0.5:
		return
	if local_mouse.y < -150.0 or local_mouse.y > 45.0:
		return
	var preferred_cell: int = _get_nearest_turret_cell(local_mouse.x)
	var target_cell: int = _grid.find_nearest_available_cell_for_type(
		BuildableType.Id.TURRET,
		preferred_cell
	)
	if target_cell < 0:
		_set_feedback("Нет свободной ячейки для турели", true)
		return
	var buildable_id: int = _grid.place(BuildableType.Id.TURRET, target_cell)
	if buildable_id < 0:
		_set_feedback("Турель не удалось установить", true)
		return
	if _buildable_input != null:
		_buildable_input.select_cell(target_cell)
	_set_feedback("Турель установлена в ячейку %d" % (target_cell + 1), false)
	get_viewport().set_input_as_handled()


func select_defender(defender_id: int) -> bool:
	return _selection.select_defender(defender_id)


func request_selected_role(role_id: int, station_id: int = -1) -> void:
	if not are_commands_enabled():
		_set_feedback("Команды сейчас недоступны", true)
		return
	_roles.request_assignment(
		_selection.get_selected_defender_id(),
		role_id,
		station_id
	)


func are_commands_enabled() -> bool:
	return _game_flow.is_world_simulation_active()


func get_defender_button_count() -> int:
	return _crew.get_total_count()


func get_turret_button_count() -> int:
	return _grid.get_count_by_type(BuildableType.Id.TURRET)


func is_standard_role_enabled(role_id: int) -> bool:
	return _roles.is_role_station_available(role_id)


func is_turret_role_enabled(buildable_id: int) -> bool:
	return _roles.is_role_station_available(CrewRole.Id.TURRET, buildable_id)


func _build_slot_specs() -> void:
	_slot_specs = [_make_slot(SlotKind.LEFT_ANCHOR, LEFT_ANCHOR_CELL)]
	for cell_index: int in LEFT_FREE_CELLS:
		_slot_specs.append(_make_slot(SlotKind.FREE_CELL, cell_index))
	_slot_specs.append(_make_slot(SlotKind.MEDIC, MEDIC_CELL))
	_slot_specs.append(_make_slot(SlotKind.DRIVER, DRIVER_CELL))
	for cell_index: int in RIGHT_FREE_CELLS:
		_slot_specs.append(_make_slot(SlotKind.FREE_CELL, cell_index))
	_slot_specs.append(_make_slot(SlotKind.RIGHT_ANCHOR, RIGHT_ANCHOR_CELL))


func _make_slot(kind: int, cell_index: int) -> Dictionary:
	return {"kind": kind, "cell": cell_index}


func _connect_signals() -> void:
	_inventory.buildable_unlocked.connect(_on_buildable_unlocked)
	_inventory.inventory_reset.connect(_on_inventory_reset)
	_grid.buildable_placed.connect(_on_buildable_changed)
	_grid.buildable_moved.connect(_on_buildable_moved)
	_grid.buildable_demolished.connect(_on_buildable_changed)
	_grid.grid_reset.connect(_on_grid_reset)
	_roles.assignment_changed.connect(_on_assignment_changed)
	_roles.assignment_rejected.connect(_on_assignment_rejected)
	_crew.defender_spawned.connect(_on_crew_changed)
	_crew.defender_replaced.connect(_on_crew_changed)
	_crew.defender_died.connect(_on_defender_died)


func _update_slots() -> void:
	for slot_index: int in range(_slot_specs.size()):
		var spec: Dictionary = _slot_specs[slot_index]
		_view.update_slot(slot_index, spec, _describe_slot(spec))


func _describe_slot(spec: Dictionary) -> Dictionary:
	var kind: int = int(spec["kind"])
	var cell_index: int = int(spec["cell"])
	var title := "СВОБОДНАЯ ЯЧЕЙКА"
	var owner_id := -1
	var available := true
	match kind:
		SlotKind.LEFT_ANCHOR:
			title = "ЛЕВЫЙ ЯКОРЬ"
			owner_id = _roles.get_role_owner(CrewRole.Id.LEFT_ANCHOR)
		SlotKind.RIGHT_ANCHOR:
			title = "ПРАВЫЙ ЯКОРЬ"
			owner_id = _roles.get_role_owner(CrewRole.Id.RIGHT_ANCHOR)
		SlotKind.DRIVER:
			title = "УПРАВЛЕНИЕ"
			owner_id = _roles.get_role_owner(CrewRole.Id.DRIVER)
		SlotKind.MEDIC:
			title = "МЕДПОСТ"
			available = _grid.get_buildable_id_by_type(
				BuildableType.Id.MEDICAL_STATION
			) >= 0
			if available:
				owner_id = _roles.get_role_owner(CrewRole.Id.MEDIC)
		SlotKind.FREE_CELL:
			var turret_id: int = _get_turret_at_cell(cell_index)
			if turret_id >= 0:
				title = "ТУРЕЛЬ T%d" % (turret_id + 1)
				owner_id = _roles.get_role_owner(CrewRole.Id.TURRET, turret_id)
			else:
				owner_id = _get_free_fighter_at_cell(cell_index)

	var occupant := "свободно"
	if not available:
		occupant = "не открыт"
	elif owner_id >= 0:
		occupant = "Защитник %d" % (owner_id + 1)
	elif kind == SlotKind.FREE_CELL and _get_turret_at_cell(cell_index) < 0:
		occupant = "—"
	return {
		"title": title,
		"occupant": occupant,
		"owner": owner_id,
		"available": available,
	}


func _on_slot_pressed(slot_index: int) -> void:
	_selected_slot = slot_index
	_rebuild_context_menu()


func _rebuild_context_menu() -> void:
	if _selected_slot < 0 or _selected_slot >= _slot_specs.size():
		_close_context()
		return
	var description: Dictionary = _describe_slot(_slot_specs[_selected_slot])
	var owner_id: int = int(description["owner"])
	var free_ids: Array[int] = _get_available_free_defenders(owner_id)
	_view.rebuild_context(
		description,
		free_ids,
		_selected_slot,
		_on_release_pressed,
		_on_assign_pressed,
		_close_context
	)


func _on_release_pressed(slot_index: int) -> void:
	var spec: Dictionary = _slot_specs[slot_index]
	var owner_id: int = int(_describe_slot(spec)["owner"])
	if owner_id < 0:
		return
	if int(spec["kind"]) == SlotKind.FREE_CELL:
		if _get_turret_at_cell(int(spec["cell"])) < 0:
			_free_cell_by_defender.erase(owner_id)
			_pending_free_moves.erase(owner_id)
			_set_feedback("Боевая ячейка освобождена", false)
			_close_context()
			return
	_release_post_owner(owner_id)
	_set_feedback("Защитник %d освобождает пост" % (owner_id + 1), false)
	_close_context()


func _on_assign_pressed(slot_index: int, defender_id: int) -> void:
	if not are_commands_enabled():
		_set_feedback("Команды сейчас недоступны", true)
		return
	var spec: Dictionary = _slot_specs[slot_index]
	var previous_owner: int = int(_describe_slot(spec)["owner"])
	if previous_owner >= 0 and previous_owner != defender_id:
		_release_post_owner(previous_owner)
	_selection.select_defender(defender_id)
	var kind: int = int(spec["kind"])
	var cell_index: int = int(spec["cell"])
	if kind == SlotKind.FREE_CELL:
		var turret_id: int = _get_turret_at_cell(cell_index)
		if turret_id < 0:
			_assign_free_fighter_to_cell(defender_id, cell_index)
		else:
			_forget_free_cell(defender_id)
			_roles.request_assignment(defender_id, CrewRole.Id.TURRET, turret_id)
	else:
		_forget_free_cell(defender_id)
		_roles.request_assignment(defender_id, _get_role_for_kind(kind))
	_set_feedback("Защитник %d назначен" % (defender_id + 1), false)
	_close_context()


func _release_post_owner(defender_id: int) -> void:
	var free_cell: int = _find_empty_free_cell()
	if free_cell >= 0:
		_free_cell_by_defender[defender_id] = free_cell
		_pending_free_moves[defender_id] = free_cell
	else:
		_forget_free_cell(defender_id)
	_roles.request_assignment(defender_id, CrewRole.Id.FREE_FIGHTER)


func _assign_free_fighter_to_cell(defender_id: int, cell_index: int) -> void:
	_free_cell_by_defender[defender_id] = cell_index
	var assignment: CrewAssignmentRuntime = _roles.get_assignment(defender_id)
	if (
		assignment != null
		and assignment.current_role == CrewRole.Id.FREE_FIGHTER
		and assignment.state == CrewAssignmentRuntime.State.ACTIVE
	):
		_move_defender_to_free_cell(defender_id, cell_index)
		return
	_pending_free_moves[defender_id] = cell_index
	_roles.request_assignment(defender_id, CrewRole.Id.FREE_FIGHTER)


func _forget_free_cell(defender_id: int) -> void:
	_free_cell_by_defender.erase(defender_id)
	_pending_free_moves.erase(defender_id)


func _move_defender_to_free_cell(defender_id: int, cell_index: int) -> void:
	var defender: Defender = _crew.get_defender(defender_id)
	if defender != null and defender.health.is_alive():
		defender.move_to(_platform.get_cell_local_x(cell_index))


func _update_pending_free_moves() -> void:
	var ids: Array = _pending_free_moves.keys()
	for raw_id: Variant in ids:
		var defender_id := int(raw_id)
		var assignment: CrewAssignmentRuntime = _roles.get_assignment(defender_id)
		if assignment == null:
			continue
		if (
			assignment.current_role == CrewRole.Id.FREE_FIGHTER
			and assignment.state == CrewAssignmentRuntime.State.ACTIVE
		):
			_move_defender_to_free_cell(
				defender_id,
				int(_pending_free_moves[defender_id])
			)
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
		if (
			assignment.current_role != CrewRole.Id.FREE_FIGHTER
			and assignment.target_role != CrewRole.Id.FREE_FIGHTER
		):
			_forget_free_cell(defender_id)


func _auto_distribute_free_fighters() -> void:
	for defender: Defender in _crew.get_living_defenders():
		if _free_cell_by_defender.has(defender.defender_id):
			continue
		var assignment: CrewAssignmentRuntime = _roles.get_assignment(defender.defender_id)
		if assignment == null:
			continue
		if (
			assignment.current_role != CrewRole.Id.FREE_FIGHTER
			or assignment.state != CrewAssignmentRuntime.State.ACTIVE
		):
			continue
		var cell_index: int = _find_empty_free_cell()
		if cell_index < 0:
			return
		_assign_free_fighter_to_cell(defender.defender_id, cell_index)


func _find_empty_free_cell() -> int:
	for cell_index: int in _grid.balance.turret_cell_indices:
		if _get_turret_at_cell(cell_index) < 0 and _get_free_fighter_at_cell(cell_index) < 0:
			return cell_index
	return -1


func _get_free_fighter_at_cell(cell_index: int) -> int:
	for raw_id: Variant in _free_cell_by_defender.keys():
		var defender_id := int(raw_id)
		if int(_free_cell_by_defender[defender_id]) != cell_index:
			continue
		var assignment: CrewAssignmentRuntime = _roles.get_assignment(defender_id)
		var defender: Defender = _crew.get_defender(defender_id)
		if (
			assignment != null
			and defender != null
			and defender.health.is_alive()
			and (
				assignment.current_role == CrewRole.Id.FREE_FIGHTER
				or assignment.target_role == CrewRole.Id.FREE_FIGHTER
			)
		):
			return defender_id
	return -1


func _get_turret_at_cell(cell_index: int) -> int:
	for buildable_id: int in _grid.get_buildable_ids_by_type(BuildableType.Id.TURRET):
		var snapshot: BuildableSnapshot = _grid.get_snapshot(buildable_id)
		if snapshot != null and snapshot.cell_index == cell_index:
			return buildable_id
	return -1


func _get_available_free_defenders(excluded_id: int) -> Array[int]:
	var result: Array[int] = []
	for defender: Defender in _crew.get_living_defenders():
		if defender.defender_id == excluded_id:
			continue
		var assignment: CrewAssignmentRuntime = _roles.get_assignment(defender.defender_id)
		if (
			assignment != null
			and assignment.current_role == CrewRole.Id.FREE_FIGHTER
			and assignment.state == CrewAssignmentRuntime.State.ACTIVE
		):
			result.append(defender.defender_id)
	return result


func _get_role_for_kind(kind: int) -> int:
	match kind:
		SlotKind.LEFT_ANCHOR:
			return CrewRole.Id.LEFT_ANCHOR
		SlotKind.RIGHT_ANCHOR:
			return CrewRole.Id.RIGHT_ANCHOR
		SlotKind.DRIVER:
			return CrewRole.Id.DRIVER
		SlotKind.MEDIC:
			return CrewRole.Id.MEDIC
	return CrewRole.Id.FREE_FIGHTER


func _can_place_turret_with_mouse() -> bool:
	if (
		_game_flow.state != GameFlowController.RunState.START_DELAY
		and _game_flow.state != GameFlowController.RunState.RUNNING
		and _game_flow.state != GameFlowController.RunState.CARD_SELECTION
	):
		return false
	return _inventory.can_deploy(
		BuildableType.Id.TURRET,
		_grid.get_count_by_type(BuildableType.Id.TURRET)
	)


func _get_nearest_turret_cell(local_x: float) -> int:
	var selected: int = _grid.balance.turret_cell_indices[0]
	var best_distance := INF
	for cell_index: int in _grid.balance.turret_cell_indices:
		var distance := absf(_platform.get_cell_local_x(cell_index) - local_x)
		if distance < best_distance:
			selected = cell_index
			best_distance = distance
	return selected


func _set_feedback(message: String, is_error: bool) -> void:
	_view.set_feedback(message, is_error)


func _close_context() -> void:
	_view.close_context()
	_selected_slot = -1


func _on_buildable_unlocked(type_id: int, _count: int) -> void:
	if type_id == BuildableType.Id.MEDICAL_STATION:
		_set_feedback("Медицинский пост доступен для установки", false)
	elif type_id == BuildableType.Id.TURRET:
		_set_feedback(
			"Турель доступна: щёлкните по свободному месту платформы",
			false
		)


func _on_inventory_reset() -> void:
	_close_context()
	_update_slots()


func _on_buildable_changed(
	_buildable_id: int,
	_type_id: int,
	_cell_index: int
) -> void:
	_update_slots()
	if _view.is_context_visible():
		_rebuild_context_menu()


func _on_buildable_moved(
	_buildable_id: int,
	_previous_cell: int,
	_cell_index: int
) -> void:
	_update_slots()


func _on_grid_reset() -> void:
	_free_cell_by_defender.clear()
	_pending_free_moves.clear()
	call_deferred("_auto_distribute_free_fighters")


func _on_assignment_changed(
	_defender_id: int,
	_current_role: int,
	_target_role: int,
	_state: int
) -> void:
	_update_slots()
	if _view.is_context_visible():
		_rebuild_context_menu()


func _on_assignment_rejected(
	defender_id: int,
	_role_id: int,
	reason: StringName
) -> void:
	_set_feedback(
		"Защитник %d: %s" % [defender_id + 1, String(reason)],
		true
	)


func _on_crew_changed(_defender_id: int, _defender: Defender) -> void:
	call_deferred("_auto_distribute_free_fighters")


func _on_defender_died(defender_id: int) -> void:
	_forget_free_cell(defender_id)
	_update_slots()
