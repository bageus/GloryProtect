class_name CrewCommandPanel
extends Control

const LEFT_ANCHOR_CELL: int = 1
const LEFT_FREE_CELLS: Array[int] = [2, 3, 4, 5]
const MEDIC_CELL: int = 7
const DRIVER_CELL: int = 10
const RIGHT_FREE_CELLS: Array[int] = [12, 13, 14, 15]
const RIGHT_ANCHOR_CELL: int = 16

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
var _configured: bool = false

var _slot_specs: Array[Dictionary] = []
var _slot_buttons: Array[Button] = []
var _free_cell_by_defender: Dictionary[int, int] = {}
var _pending_free_moves: Dictionary[int, int] = {}
var _selected_slot: int = -1
var _context_panel: PanelContainer
var _context_box: VBoxContainer
var _feedback_label: Label


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
	var scene_root: Node = get_tree().current_scene
	if scene_root != null:
		_buildable_input = scene_root.get_node_or_null(
			"BuildableDebugInput"
		) as BuildableDebugInput
	_configured = true


func _ready() -> void:
	assert(_configured, "CrewCommandPanel must be configured before entering tree")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_slot_specs()
	_build_interface()
	_connect_signals()
	call_deferred("_ensure_medical_station")
	call_deferred("_auto_distribute_free_fighters")
	_update_slots()


func _process(_delta: float) -> void:
	visible = _game_flow.state != GameFlowController.RunState.GAME_OVER
	if not visible:
		return
	_update_pending_free_moves()
	_cleanup_free_assignments()
	_auto_distribute_free_fighters()
	_update_slots()
	if _context_panel.visible:
		_rebuild_context_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if (
		mouse_event.button_index != MOUSE_BUTTON_LEFT
		or not mouse_event.pressed
	):
		return
	if not _can_place_turret_with_mouse():
		return
	var local_mouse: Vector2 = _platform.get_local_mouse_position()
	var half_width: float = _platform.get_platform_width() * 0.5
	if absf(local_mouse.x) > half_width:
		return
	if (
		local_mouse.y < -150.0
		or local_mouse.y > _platform.get_platform_height() * 0.75
	):
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
	if not _commands_enabled():
		_set_feedback("Команды сейчас недоступны", true)
		return
	_roles.request_assignment(
		_selection.get_selected_defender_id(),
		role_id,
		station_id
	)


func are_commands_enabled() -> bool:
	return _commands_enabled()


func get_defender_button_count() -> int:
	return _crew.get_total_count()


func get_turret_button_count() -> int:
	return _grid.get_count_by_type(BuildableType.Id.TURRET)


func is_standard_role_enabled(role_id: int) -> bool:
	return _roles.is_role_station_available(role_id)


func is_turret_role_enabled(buildable_id: int) -> bool:
	return _roles.is_role_station_available(CrewRole.Id.TURRET, buildable_id)


func _build_slot_specs() -> void:
	_slot_specs.clear()
	_slot_specs.append(_make_slot(SlotKind.LEFT_ANCHOR, LEFT_ANCHOR_CELL))
	for cell_index: int in LEFT_FREE_CELLS:
		_slot_specs.append(_make_slot(SlotKind.FREE_CELL, cell_index))
	_slot_specs.append(_make_slot(SlotKind.MEDIC, MEDIC_CELL))
	_slot_specs.append(_make_slot(SlotKind.DRIVER, DRIVER_CELL))
	for cell_index: int in RIGHT_FREE_CELLS:
		_slot_specs.append(_make_slot(SlotKind.FREE_CELL, cell_index))
	_slot_specs.append(_make_slot(SlotKind.RIGHT_ANCHOR, RIGHT_ANCHOR_CELL))


func _make_slot(kind: int, cell_index: int) -> Dictionary:
	return {
		"kind": kind,
		"cell": cell_index,
	}


func _build_interface() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 0.0
	offset_top = -142.0
	offset_right = 0.0
	offset_bottom = 0.0

	_build_side_panel(true, 0, 6)
	_build_side_panel(false, 6, 12)
	_build_context_panel()

	_feedback_label = Label.new()
	_feedback_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_feedback_label.offset_left = 210.0
	_feedback_label.offset_top = -141.0
	_feedback_label.offset_right = -210.0
	_feedback_label.offset_bottom = -118.0
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 13)
	_feedback_label.add_theme_color_override(
		"font_color",
		Color(0.72, 0.82, 0.92)
	)
	_feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feedback_label)


func _build_side_panel(is_left: bool, begin: int, end: int) -> void:
	var panel := PanelContainer.new()
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -116.0
	panel.offset_bottom = -8.0
	if is_left:
		panel.anchor_left = 0.0
		panel.anchor_right = 0.5
		panel.offset_left = 8.0
		panel.offset_right = -96.0
	else:
		panel.anchor_left = 0.5
		panel.anchor_right = 1.0
		panel.offset_left = 96.0
		panel.offset_right = -8.0
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	margin.add_child(row)
	for slot_index: int in range(begin, end):
		var button := Button.new()
		button.custom_minimum_size = Vector2(68.0, 92.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(_on_slot_pressed.bind(slot_index))
		row.add_child(button)
		_slot_buttons.append(button)


func _build_context_panel() -> void:
	_context_panel = PanelContainer.new()
	_context_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_context_panel.offset_left = -210.0
	_context_panel.offset_top = -330.0
	_context_panel.offset_right = 210.0
	_context_panel.offset_bottom = -148.0
	_context_panel.add_theme_stylebox_override("panel", _make_context_style())
	_context_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_context_panel.visible = false
	add_child(_context_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_context_panel.add_child(margin)
	_context_box = VBoxContainer.new()
	_context_box.add_theme_constant_override("separation", 5)
	margin.add_child(_context_box)


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.055, 0.94)
	style.border_color = Color(0.2, 0.34, 0.48, 0.95)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


func _make_context_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.026, 0.043, 0.98)
	style.border_color = Color(0.34, 0.56, 0.76, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style


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
		var button: Button = _slot_buttons[slot_index]
		var description: Dictionary = _describe_slot(spec)
		button.text = "%s\n%s" % [
			description["title"],
			description["occupant"],
		]
		button.disabled = not bool(description["available"])
		button.tooltip_text = "Ячейка платформы %d" % (int(spec["cell"]) + 1)


func _describe_slot(spec: Dictionary) -> Dictionary:
	var kind: int = int(spec["kind"])
	var cell_index: int = int(spec["cell"])
	var title: String = "СВОБОДНАЯ ЯЧЕЙКА"
	var owner_id: int = -1
	var available: bool = true

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

	var occupant: String = "свободно"
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
	_context_panel.visible = true
	_rebuild_context_menu()


func _rebuild_context_menu() -> void:
	_clear_children(_context_box)
	if _selected_slot < 0 or _selected_slot >= _slot_specs.size():
		_context_panel.visible = false
		return
	var spec: Dictionary = _slot_specs[_selected_slot]
	var description: Dictionary = _describe_slot(spec)

	var title := Label.new()
	title.text = String(description["title"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	_context_box.add_child(title)

	if not bool(description["available"]):
		var unavailable := Label.new()
		unavailable.text = "Пост появится после получения улучшения"
		unavailable.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_context_box.add_child(unavailable)
		_add_close_button()
		return

	var owner_id: int = int(description["owner"])
	if owner_id >= 0:
		var release := Button.new()
		release.text = "Освободить пост — защитник %d" % (owner_id + 1)
		release.pressed.connect(_on_release_pressed.bind(_selected_slot))
		_context_box.add_child(release)

	var free_ids: Array[int] = _get_available_free_defenders(owner_id)
	if free_ids.is_empty():
		var empty := Label.new()
		empty.text = "Свободных защитников нет"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_context_box.add_child(empty)
	else:
		var hint := Label.new()
		hint.text = "Назначить свободного защитника:"
		_context_box.add_child(hint)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 5)
		_context_box.add_child(row)
		for defender_id: int in free_ids:
			var button := Button.new()
			button.text = "Защитник %d" % (defender_id + 1)
			button.pressed.connect(
				_on_assign_pressed.bind(_selected_slot, defender_id)
			)
			row.add_child(button)
	_add_close_button()


func _add_close_button() -> void:
	var close := Button.new()
	close.text = "Закрыть"
	close.pressed.connect(_close_context)
	_context_box.add_child(close)


func _on_release_pressed(slot_index: int) -> void:
	var owner_id: int = int(_describe_slot(_slot_specs[slot_index])["owner"])
	if owner_id < 0:
		return
	var spec: Dictionary = _slot_specs[slot_index]
	if int(spec["kind"]) == SlotKind.FREE_CELL:
		var turret_id: int = _get_turret_at_cell(int(spec["cell"]))
		if turret_id < 0:
			_free_cell_by_defender.erase(owner_id)
			_pending_free_moves.erase(owner_id)
			_set_feedback("Боевая ячейка освобождена", false)
			_close_context()
			return
	_release_post_owner(owner_id)
	_set_feedback("Защитник %d освобождает пост" % (owner_id + 1), false)
	_close_context()


func _on_assign_pressed(slot_index: int, defender_id: int) -> void:
	if not _commands_enabled():
		_set_feedback("Команды сейчас недоступны", true)
		return
	var spec: Dictionary = _slot_specs[slot_index]
	var description: Dictionary = _describe_slot(spec)
	var previous_owner: int = int(description["owner"])
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
			_free_cell_by_defender.erase(defender_id)
			_roles.request_assignment(
				defender_id,
				CrewRole.Id.TURRET,
				turret_id
			)
	else:
		_free_cell_by_defender.erase(defender_id)
		_pending_free_moves.erase(defender_id)
		var role_id: int = _get_role_for_kind(kind)
		_roles.request_assignment(defender_id, role_id)
	_set_feedback("Защитник %d назначен" % (defender_id + 1), false)
	_close_context()


func _release_post_owner(defender_id: int) -> void:
	var free_cell: int = _find_empty_free_cell()
	if free_cell >= 0:
		_free_cell_by_defender[defender_id] = free_cell
		_pending_free_moves[defender_id] = free_cell
	else:
		_free_cell_by_defender.erase(defender_id)
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


func _move_defender_to_free_cell(defender_id: int, cell_index: int) -> void:
	var defender: Defender = _crew.get_defender(defender_id)
	if defender == null or not defender.health.is_alive():
		return
	defender.move_to(_platform.get_cell_local_x(cell_index))


func _update_pending_free_moves() -> void:
	var defender_ids: Array[int] = _pending_free_moves.keys()
	for defender_id: int in defender_ids:
		var assignment: CrewAssignmentRuntime = _roles.get_assignment(defender_id)
		if assignment == null:
			continue
		if (
			assignment.current_role != CrewRole.Id.FREE_FIGHTER
			or assignment.state != CrewAssignmentRuntime.State.ACTIVE
		):
			continue
		_move_defender_to_free_cell(
			defender_id,
			int(_pending_free_moves[defender_id])
		)
		_pending_free_moves.erase(defender_id)


func _cleanup_free_assignments() -> void:
	var defender_ids: Array[int] = _free_cell_by_defender.keys()
	for defender_id: int in defender_ids:
		var defender: Defender = _crew.get_defender(defender_id)
		var assignment: CrewAssignmentRuntime = _roles.get_assignment(defender_id)
		if defender == null or assignment == null or not defender.health.is_alive():
			_free_cell_by_defender.erase(defender_id)
			_pending_free_moves.erase(defender_id)
			continue
		if (
			assignment.current_role != CrewRole.Id.FREE_FIGHTER
			and assignment.target_role != CrewRole.Id.FREE_FIGHTER
		):
			_free_cell_by_defender.erase(defender_id)
			_pending_free_moves.erase(defender_id)


func _auto_distribute_free_fighters() -> void:
	for defender: Defender in _crew.get_living_defenders():
		if _free_cell_by_defender.has(defender.defender_id):
			continue
		var assignment: CrewAssignmentRuntime = _roles.get_assignment(
			defender.defender_id
		)
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
		if _get_turret_at_cell(cell_index) >= 0:
			continue
		if _get_free_fighter_at_cell(cell_index) >= 0:
			continue
		return cell_index
	return -1


func _get_free_fighter_at_cell(cell_index: int) -> int:
	for defender_id: int in _free_cell_by_defender:
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
	for buildable_id: int in _grid.get_buildable_ids_by_type(
		BuildableType.Id.TURRET
	):
		var snapshot: BuildableSnapshot = _grid.get_snapshot(buildable_id)
		if snapshot != null and snapshot.cell_index == cell_index:
			return buildable_id
	return -1


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


func _ensure_medical_station() -> void:
	if not _inventory.is_unlocked(BuildableType.Id.MEDICAL_STATION):
		return
	if _grid.get_buildable_id_by_type(BuildableType.Id.MEDICAL_STATION) >= 0:
		return
	var buildable_id: int = _grid.place(
		BuildableType.Id.MEDICAL_STATION,
		_grid.balance.default_medical_cell
	)
	if buildable_id >= 0:
		_set_feedback("Медицинский пост установлен автоматически", false)


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
	var best_distance: float = INF
	for cell_index: int in _grid.balance.turret_cell_indices:
		var distance: float = absf(
			_platform.get_cell_local_x(cell_index) - local_x
		)
		if distance < best_distance:
			selected = cell_index
			best_distance = distance
	return selected


func _commands_enabled() -> bool:
	return _game_flow.is_world_simulation_active()


func _set_feedback(message: String, is_error: bool) -> void:
	_feedback_label.text = message
	_feedback_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.48, 0.4) if is_error else Color(0.62, 0.92, 0.72)
	)


func _close_context() -> void:
	_context_panel.visible = false
	_selected_slot = -1


func _clear_children(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _on_buildable_unlocked(type_id: int, _count: int) -> void:
	if type_id == BuildableType.Id.MEDICAL_STATION:
		call_deferred("_ensure_medical_station")
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
	_auto_distribute_free_fighters()
	_update_slots()


func _on_buildable_moved(
	_buildable_id: int,
	_previous_cell: int,
	_cell_index: int
) -> void:
	_update_slots()


func _on_grid_reset() -> void:
	_free_cell_by_defender.clear()
	_pending_free_moves.clear()
	call_deferred("_ensure_medical_station")
	call_deferred("_auto_distribute_free_fighters")


func _on_assignment_changed(
	_defender_id: int,
	_current_role: int,
	_target_role: int,
	_state: int
) -> void:
	_update_slots()


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
	_free_cell_by_defender.erase(defender_id)
	_pending_free_moves.erase(defender_id)
	_update_slots()
