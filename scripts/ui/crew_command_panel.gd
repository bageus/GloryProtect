class_name CrewCommandPanel
extends Control

const STANDARD_ROLES: Array[int] = [
	CrewRole.Id.FREE_FIGHTER,
	CrewRole.Id.DRIVER,
	CrewRole.Id.LEFT_ANCHOR,
	CrewRole.Id.RIGHT_ANCHOR,
	CrewRole.Id.MEDIC,
]

var _game_flow: GameFlowController
var _selection: CrewSelectionController
var _crew: CrewManager
var _roles: CrewRoleManager
var _replacements: CrewReplacementController
var _grid: BuildableGrid
var _configured: bool = false

var _defender_group: ButtonGroup = ButtonGroup.new()
var _defender_buttons: Dictionary[int, Button] = {}
var _role_buttons: Dictionary[int, Button] = {}
var _turret_buttons: Dictionary[int, Button] = {}

var _selection_label: Label
var _defender_row: HBoxContainer
var _role_row: HBoxContainer
var _turret_row: HBoxContainer
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
	_configured = true


func _ready() -> void:
	assert(_configured, "CrewCommandPanel must be configured before entering tree")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_layout()
	_connect_signals()
	_rebuild_defender_buttons()
	_rebuild_role_buttons()
	_rebuild_turret_buttons()
	_update_view()


func _process(_delta: float) -> void:
	visible = (
		_game_flow.state != GameFlowController.RunState.CARD_SELECTION
		and _game_flow.state != GameFlowController.RunState.GAME_OVER
	)
	if visible:
		_update_view()


func select_defender(defender_id: int) -> bool:
	return _selection.select_defender(defender_id)


func request_selected_role(role_id: int, station_id: int = -1) -> void:
	if not are_commands_enabled():
		_set_feedback("Команды недоступны в текущем состоянии игры", true)
		return
	_roles.request_assignment(
		_selection.get_selected_defender_id(),
		role_id,
		station_id
	)
	_set_feedback("Команда отправлена", false)


func are_commands_enabled() -> bool:
	if not _game_flow.is_world_simulation_active():
		return false
	var defender: Defender = _selection.get_selected_defender()
	if defender == null or not defender.health.is_alive():
		return false
	var assignment: CrewAssignmentRuntime = _roles.get_assignment(
		defender.defender_id
	)
	return (
		assignment != null
		and assignment.state == CrewAssignmentRuntime.State.ACTIVE
	)


func get_defender_button_count() -> int:
	return _defender_buttons.size()


func get_turret_button_count() -> int:
	return _turret_buttons.size()


func is_standard_role_enabled(role_id: int) -> bool:
	var button: Button = _role_buttons.get(role_id)
	return button != null and not button.disabled


func is_turret_role_enabled(buildable_id: int) -> bool:
	var button: Button = _turret_buttons.get(buildable_id)
	return button != null and not button.disabled


func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 16.0
	offset_top = -252.0
	offset_right = -16.0
	offset_bottom = -16.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)

	var title := Label.new()
	title.text = "УПРАВЛЕНИЕ ЭКИПАЖЕМ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	content.add_child(title)

	_defender_row = HBoxContainer.new()
	_defender_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_defender_row.add_theme_constant_override("separation", 8)
	content.add_child(_defender_row)

	_selection_label = Label.new()
	_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_selection_label)

	_role_row = HBoxContainer.new()
	_role_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_role_row.add_theme_constant_override("separation", 6)
	content.add_child(_role_row)

	var turret_title := Label.new()
	turret_title.text = "ТУРЕЛИ"
	turret_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turret_title.add_theme_font_size_override("font_size", 15)
	content.add_child(turret_title)

	var turret_scroll := ScrollContainer.new()
	turret_scroll.custom_minimum_size = Vector2(0.0, 46.0)
	turret_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	turret_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(turret_scroll)

	_turret_row = HBoxContainer.new()
	_turret_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turret_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_turret_row.add_theme_constant_override("separation", 6)
	turret_scroll.add_child(_turret_row)

	_feedback_label = Label.new()
	_feedback_label.text = "Выберите защитника и назначьте роль"
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_color_override(
		"font_color",
		Color(0.72, 0.8, 0.88)
	)
	content.add_child(_feedback_label)


func _connect_signals() -> void:
	_selection.selected_defender_changed.connect(_on_selection_changed)
	_roles.assignment_changed.connect(_on_assignment_changed)
	_roles.assignment_rejected.connect(_on_assignment_rejected)
	_crew.defender_spawned.connect(_on_crew_changed)
	_crew.defender_replaced.connect(_on_crew_changed)
	_crew.defender_died.connect(_on_defender_died)
	_replacements.replacement_started.connect(_on_replacement_started)
	_replacements.replacement_completed.connect(_on_replacement_completed)
	_grid.buildable_placed.connect(_on_buildable_changed)
	_grid.buildable_moved.connect(_on_buildable_moved)
	_grid.buildable_demolished.connect(_on_buildable_changed)
	_grid.grid_reset.connect(_on_grid_reset)


func _rebuild_defender_buttons() -> void:
	_clear_children(_defender_row)
	_defender_buttons.clear()
	for defender_id: int in range(_crew.balance.maximum_defender_count):
		var button := Button.new()
		button.custom_minimum_size = Vector2(154.0, 54.0)
		button.toggle_mode = true
		button.button_group = _defender_group
		button.pressed.connect(_on_defender_pressed.bind(defender_id))
		_defender_row.add_child(button)
		_defender_buttons[defender_id] = button


func _rebuild_role_buttons() -> void:
	_clear_children(_role_row)
	_role_buttons.clear()
	for role_id: int in STANDARD_ROLES:
		var button := Button.new()
		button.custom_minimum_size = Vector2(140.0, 40.0)
		button.pressed.connect(_on_role_pressed.bind(role_id))
		_role_row.add_child(button)
		_role_buttons[role_id] = button


func _rebuild_turret_buttons() -> void:
	_clear_children(_turret_row)
	_turret_buttons.clear()
	for buildable_id: int in _grid.get_buildable_ids_by_type(
		BuildableType.Id.TURRET
	):
		var button := Button.new()
		button.custom_minimum_size = Vector2(188.0, 40.0)
		button.pressed.connect(_on_turret_pressed.bind(buildable_id))
		_turret_row.add_child(button)
		_turret_buttons[buildable_id] = button
	if _turret_buttons.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Установленных турелей нет"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_turret_row.add_child(empty_label)


func _update_view() -> void:
	_update_defender_buttons()
	_update_selection_label()
	_update_role_buttons()
	_update_turret_buttons()


func _update_defender_buttons() -> void:
	var selected_id: int = _selection.get_selected_defender_id()
	for defender_id: int in _defender_buttons:
		var button: Button = _defender_buttons[defender_id]
		var defender: Defender = _crew.get_defender(defender_id)
		button.button_pressed = defender_id == selected_id
		button.disabled = defender == null
		if defender == null:
			button.text = "Защитник %d\nНЕДОСТУПЕН" % (defender_id + 1)
			continue
		var role_text: String = _get_assignment_short_text(defender_id)
		if _replacements.is_replacement_pending(defender_id):
			button.text = "Защитник %d\nЗамена %.1fс" % [
				defender_id + 1,
				_replacements.get_remaining_seconds(defender_id),
			]
		else:
			button.text = "Защитник %d  HP %d/%d\n%s" % [
				defender_id + 1,
				defender.health.current_health,
				defender.health.max_health,
				role_text,
			]


func _update_selection_label() -> void:
	var defender_id: int = _selection.get_selected_defender_id()
	var defender: Defender = _crew.get_defender(defender_id)
	if defender == null:
		_selection_label.text = "Выбранный защитник недоступен"
		return
	var assignment: CrewAssignmentRuntime = _roles.get_assignment(defender_id)
	var state_text: String = "не инициализирован"
	if assignment != null:
		state_text = _get_assignment_long_text(assignment)
	_selection_label.text = "Выбран защитник %d • HP %d/%d • %s" % [
		defender_id + 1,
		defender.health.current_health,
		defender.health.max_health,
		state_text,
	]


func _update_role_buttons() -> void:
	for role_id: int in STANDARD_ROLES:
		var button: Button = _role_buttons[role_id]
		_update_role_button(button, role_id, -1)


func _update_turret_buttons() -> void:
	for buildable_id: int in _turret_buttons:
		var button: Button = _turret_buttons[buildable_id]
		var snapshot: BuildableSnapshot = _grid.get_snapshot(buildable_id)
		if snapshot == null:
			button.disabled = true
			button.text = "Турель удалена"
			continue
		var owner_id: int = _roles.get_role_owner(
			CrewRole.Id.TURRET,
			buildable_id
		)
		button.text = "Турель T%d • клетка %d\n%s" % [
			buildable_id + 1,
			snapshot.cell_index + 1,
			_get_owner_text(owner_id),
		]
		button.disabled = not _can_assign_station(
			CrewRole.Id.TURRET,
			buildable_id,
			owner_id
		)


func _update_role_button(button: Button, role_id: int, station_id: int) -> void:
	var owner_id: int = _roles.get_role_owner(role_id, station_id)
	button.text = "%s\n%s" % [
		_get_role_title(role_id),
		_get_owner_text(owner_id),
	]
	button.disabled = not _can_assign_station(role_id, station_id, owner_id)


func _can_assign_station(role_id: int, station_id: int, owner_id: int) -> bool:
	if not are_commands_enabled():
		return false
	var selected_id: int = _selection.get_selected_defender_id()
	var assignment: CrewAssignmentRuntime = _roles.get_assignment(selected_id)
	if assignment == null:
		return false
	var normalized_station_id: int = station_id
	if role_id == CrewRole.Id.MEDIC and station_id < 0:
		normalized_station_id = CrewRoleManager.DEFAULT_DYNAMIC_STATION_ID
	if (
		assignment.current_role == role_id
		and assignment.current_station_id == normalized_station_id
	):
		return false
	if not _roles.is_role_station_available(role_id, station_id):
		return false
	return owner_id < 0 or owner_id == selected_id


func _get_owner_text(owner_id: int) -> String:
	if owner_id < 0:
		return "свободно"
	if owner_id == _selection.get_selected_defender_id():
		return "занято выбранным"
	return "занято защитником %d" % (owner_id + 1)


func _get_assignment_short_text(defender_id: int) -> String:
	var assignment: CrewAssignmentRuntime = _roles.get_assignment(defender_id)
	if assignment == null:
		return "ИНИЦИАЛИЗАЦИЯ"
	var result: String = _get_role_title(assignment.current_role)
	if assignment.state != CrewAssignmentRuntime.State.ACTIVE:
		result += " → %s" % _get_role_title(assignment.target_role)
	return result


func _get_assignment_long_text(assignment: CrewAssignmentRuntime) -> String:
	var current: String = _get_role_title(assignment.current_role)
	if assignment.current_role == CrewRole.Id.TURRET:
		current += " T%d" % (assignment.current_station_id + 1)
	match assignment.state:
		CrewAssignmentRuntime.State.ACTIVE:
			return "роль: %s" % current
		CrewAssignmentRuntime.State.MOVING:
			return "движется: %s → %s" % [
				current,
				_get_target_title(assignment),
			]
		CrewAssignmentRuntime.State.WAITING_FOR_ACTION:
			return "завершает действие, затем → %s" % _get_target_title(
				assignment
			)
		CrewAssignmentRuntime.State.DEAD:
			return "погиб"
		_:
			return current


func _get_target_title(assignment: CrewAssignmentRuntime) -> String:
	var result: String = _get_role_title(assignment.target_role)
	if assignment.target_role == CrewRole.Id.TURRET:
		result += " T%d" % (assignment.target_station_id + 1)
	return result


func _get_role_title(role_id: int) -> String:
	match role_id:
		CrewRole.Id.FREE_FIGHTER:
			return "Свободный боец"
		CrewRole.Id.DRIVER:
			return "Рулевой"
		CrewRole.Id.LEFT_ANCHOR:
			return "Левый якорщик"
		CrewRole.Id.RIGHT_ANCHOR:
			return "Правый якорщик"
		CrewRole.Id.MEDIC:
			return "Лекарь"
		CrewRole.Id.TURRET:
			return "Турельщик"
		_:
			return "Неизвестная роль"


func _set_feedback(message: String, is_error: bool) -> void:
	_feedback_label.text = message
	var color := Color(0.65, 0.9, 0.75)
	if is_error:
		color = Color(1.0, 0.5, 0.42)
	_feedback_label.add_theme_color_override("font_color", color)


func _get_rejection_text(reason: StringName) -> String:
	match reason:
		&"unknown_defender":
			return "Защитник не найден"
		&"role_unavailable":
			return "Рабочий пост ещё не установлен"
		&"defender_dead":
			return "Погибшему защитнику нельзя назначить роль"
		&"defender_busy":
			return "Защитник уже выполняет переход или ожидает завершения действия"
		&"station_occupied":
			return "Этот рабочий пост уже занят"
		_:
			return "Команда отклонена: %s" % String(reason)


func _clear_children(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _on_defender_pressed(defender_id: int) -> void:
	select_defender(defender_id)


func _on_role_pressed(role_id: int) -> void:
	request_selected_role(role_id)


func _on_turret_pressed(buildable_id: int) -> void:
	request_selected_role(CrewRole.Id.TURRET, buildable_id)


func _on_selection_changed(_defender_id: int) -> void:
	_set_feedback("Защитник выбран", false)
	_update_view()


func _on_assignment_changed(
	defender_id: int,
	_current_role: int,
	_target_role: int,
	_state: int
) -> void:
	if defender_id == _selection.get_selected_defender_id():
		_set_feedback("Назначение обновлено", false)
	_update_view()


func _on_assignment_rejected(
	defender_id: int,
	_role_id: int,
	reason: StringName
) -> void:
	if defender_id == _selection.get_selected_defender_id():
		_set_feedback(_get_rejection_text(reason), true)
	_update_view()


func _on_crew_changed(_defender_id: int, _defender: Defender) -> void:
	_rebuild_defender_buttons()
	_update_view()


func _on_defender_died(_defender_id: int) -> void:
	_update_view()


func _on_replacement_started(
	_defender_id: int,
	_duration_seconds: float
) -> void:
	_update_view()


func _on_replacement_completed(
	_defender_id: int,
	_defender: Defender
) -> void:
	_rebuild_defender_buttons()
	_update_view()


func _on_buildable_changed(
	_buildable_id: int,
	_type_id: int,
	_cell_index: int
) -> void:
	_rebuild_turret_buttons()
	_update_view()


func _on_buildable_moved(
	_buildable_id: int,
	_previous_cell: int,
	_cell_index: int
) -> void:
	_update_view()


func _on_grid_reset() -> void:
	_rebuild_turret_buttons()
	_update_view()
