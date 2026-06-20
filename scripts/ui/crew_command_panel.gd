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
var _view: CrewCommandPanelView = CrewCommandPanelView.new()


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
	_view.build(self)
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
		_view.set_feedback(
			"Команды недоступны в текущем состоянии игры",
			true
		)
		return
	_roles.request_assignment(
		_selection.get_selected_defender_id(),
		role_id,
		station_id
	)
	_view.set_feedback("Команда отправлена", false)


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
	return _view.defender_buttons.size()


func get_turret_button_count() -> int:
	return _view.turret_buttons.size()


func is_standard_role_enabled(role_id: int) -> bool:
	var button: Button = _view.role_buttons.get(role_id)
	return button != null and not button.disabled


func is_turret_role_enabled(buildable_id: int) -> bool:
	var button: Button = _view.turret_buttons.get(buildable_id)
	return button != null and not button.disabled


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
	_view.rebuild_defender_buttons(
		_crew.balance.maximum_defender_count,
		_on_defender_pressed
	)


func _rebuild_role_buttons() -> void:
	_view.rebuild_role_buttons(STANDARD_ROLES, _on_role_pressed)


func _rebuild_turret_buttons() -> void:
	_view.rebuild_turret_buttons(
		_grid.get_buildable_ids_by_type(BuildableType.Id.TURRET),
		_on_turret_pressed
	)


func _update_view() -> void:
	_update_defender_buttons()
	_update_selection_label()
	_update_role_buttons()
	_update_turret_buttons()


func _update_defender_buttons() -> void:
	var selected_id: int = _selection.get_selected_defender_id()
	for defender_id: int in _view.defender_buttons:
		var button: Button = _view.defender_buttons[defender_id]
		var defender: Defender = _crew.get_defender(defender_id)
		button.button_pressed = defender_id == selected_id
		button.disabled = defender == null
		if defender == null:
			button.text = "Защитник %d\nНЕДОСТУПЕН" % (defender_id + 1)
			continue
		if _replacements.is_replacement_pending(defender_id):
			button.text = "Защитник %d\nЗамена %.1fс" % [
				defender_id + 1,
				_replacements.get_remaining_seconds(defender_id),
			]
			continue
		button.text = "Защитник %d  HP %d/%d\n%s" % [
			defender_id + 1,
			defender.health.current_health,
			defender.health.max_health,
			CrewCommandText.assignment_short(
				_roles.get_assignment(defender_id)
			),
		]


func _update_selection_label() -> void:
	var defender_id: int = _selection.get_selected_defender_id()
	var defender: Defender = _crew.get_defender(defender_id)
	if defender == null:
		_view.selection_label.text = "Выбранный защитник недоступен"
		return
	_view.selection_label.text = "Выбран защитник %d • HP %d/%d • %s" % [
		defender_id + 1,
		defender.health.current_health,
		defender.health.max_health,
		CrewCommandText.assignment_long(
			_roles.get_assignment(defender_id)
		),
	]


func _update_role_buttons() -> void:
	for role_id: int in STANDARD_ROLES:
		var button: Button = _view.role_buttons[role_id]
		var owner_id: int = _roles.get_role_owner(role_id)
		button.text = "%s\n%s" % [
			CrewCommandText.role_title(role_id),
			CrewCommandText.owner_text(
				owner_id,
				_selection.get_selected_defender_id()
			),
		]
		button.disabled = not _can_assign_station(role_id, -1, owner_id)


func _update_turret_buttons() -> void:
	for buildable_id: int in _view.turret_buttons:
		var button: Button = _view.turret_buttons[buildable_id]
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
			CrewCommandText.owner_text(
				owner_id,
				_selection.get_selected_defender_id()
			),
		]
		button.disabled = not _can_assign_station(
			CrewRole.Id.TURRET,
			buildable_id,
			owner_id
		)


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


func _on_defender_pressed(defender_id: int) -> void:
	select_defender(defender_id)


func _on_role_pressed(role_id: int) -> void:
	request_selected_role(role_id)


func _on_turret_pressed(buildable_id: int) -> void:
	request_selected_role(CrewRole.Id.TURRET, buildable_id)


func _on_selection_changed(_defender_id: int) -> void:
	_view.set_feedback("Защитник выбран", false)
	_update_view()


func _on_assignment_changed(
	defender_id: int,
	_current_role: int,
	_target_role: int,
	_state: int
) -> void:
	if defender_id == _selection.get_selected_defender_id():
		_view.set_feedback("Назначение обновлено", false)
	_update_view()


func _on_assignment_rejected(
	defender_id: int,
	_role_id: int,
	reason: StringName
) -> void:
	if defender_id == _selection.get_selected_defender_id():
		_view.set_feedback(CrewCommandText.rejection_text(reason), true)
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
