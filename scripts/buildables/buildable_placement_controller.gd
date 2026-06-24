class_name BuildablePlacementController
extends Node

signal mode_changed(mode: int, type_id: int, buildable_id: int)
signal hovered_cell_changed(cell_index: int)
signal selected_buildable_changed(buildable_id: int)
signal selected_turret_changed(buildable_id: int)
signal feedback_changed(message: String, is_error: bool)


enum Mode {
	IDLE,
	PLACE,
	MOVE,
}

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("BuildableInventory") var inventory_path: NodePath
@export_node_path("BuildableGrid") var grid_path: NodePath

var mode: Mode = Mode.IDLE
var selected_type_id: int = -1
var selected_buildable_id: int = -1
var hovered_cell_index: int = -1
var _feedback_message: String = "Выберите тип объекта"
var _feedback_is_error: bool = false

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _platform: PlatformController = get_node(platform_path)
@onready var _inventory: BuildableInventory = get_node(inventory_path)
@onready var _grid: BuildableGrid = get_node(grid_path)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_grid.buildable_demolished.connect(_on_buildable_demolished)
	_grid.grid_reset.connect(_on_grid_reset)
	_game_flow.run_state_changed.connect(_on_run_state_changed)
	feedback_changed.emit(_feedback_message, _feedback_is_error)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		handle_pointer_motion((event as InputEventMouseMotion).position)
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_current_action()
		get_viewport().set_input_as_handled()
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if handle_primary_click(mouse_event.position):
		get_viewport().set_input_as_handled()


func are_commands_enabled() -> bool:
	return _game_flow.state == GameFlowController.RunState.RUNNING


func begin_placement(type_id: int) -> bool:
	if not _ensure_commands_enabled():
		return false
	selected_type_id = type_id
	_set_selected_buildable(-1)
	if not _inventory.is_unlocked(type_id):
		_set_mode(Mode.IDLE)
		_set_feedback("Объект ещё не открыт улучшением", true)
		return false
	if not _inventory.can_deploy(type_id, _grid.get_count_by_type(type_id)):
		_set_mode(Mode.IDLE)
		_set_feedback("Все доступные объекты этого типа уже установлены", true)
		return false
	_set_mode(Mode.PLACE)
	_set_feedback(
		"Выберите зелёную клетку для объекта «%s»" % _get_type_title(type_id),
		false
	)
	return true


func select_buildable(buildable_id: int) -> bool:
	var snapshot: BuildableSnapshot = _grid.get_snapshot(buildable_id)
	if snapshot == null:
		_set_feedback("Объект больше не существует", true)
		return false
	selected_type_id = snapshot.type_id
	_set_selected_buildable(buildable_id)
	_set_mode(Mode.IDLE)
	_set_feedback(
		"Выбран объект «%s» в клетке %d" % [
			_get_type_title(snapshot.type_id),
			snapshot.cell_index + 1,
		],
		false
	)
	return true


func begin_move_selected() -> bool:
	if not _ensure_commands_enabled():
		return false
	var snapshot: BuildableSnapshot = _grid.get_snapshot(selected_buildable_id)
	if snapshot == null:
		_set_feedback("Сначала выберите установленный объект", true)
		return false
	selected_type_id = snapshot.type_id
	_set_mode(Mode.MOVE)
	_set_feedback("Выберите новую зелёную клетку", false)
	return true


func demolish_selected() -> bool:
	if not _ensure_commands_enabled():
		return false
	var snapshot: BuildableSnapshot = _grid.get_snapshot(selected_buildable_id)
	if snapshot == null:
		_set_feedback("Сначала выберите установленный объект", true)
		return false
	var title := _get_type_title(snapshot.type_id)
	if not _grid.demolish(selected_buildable_id):
		_set_feedback("Не удалось демонтировать объект", true)
		return false
	_set_feedback("Объект «%s» демонтирован" % title, false)
	return true


func cancel_current_action() -> void:
	_set_mode(Mode.IDLE)
	if selected_buildable_id < 0:
		selected_type_id = -1
	_set_feedback("Действие отменено", false)


func clear_selection() -> void:
	selected_type_id = -1
	_set_selected_buildable(-1)
	_set_mode(Mode.IDLE)
	_set_feedback("Выберите тип объекта", false)


func handle_pointer_motion(canvas_position: Vector2) -> int:
	var next_cell := _platform.get_cell_index_at_canvas_position(canvas_position)
	if next_cell == hovered_cell_index:
		return next_cell
	hovered_cell_index = next_cell
	hovered_cell_changed.emit(hovered_cell_index)
	return next_cell


func handle_primary_click(canvas_position: Vector2) -> bool:
	var cell_index := handle_pointer_motion(canvas_position)
	if cell_index < 0:
		return false
	if not _ensure_commands_enabled():
		return true
	var occupant_id := _grid.get_buildable_id_at_cell(cell_index)
	if mode == Mode.MOVE:
		return _move_selected_to(cell_index)
	if mode == Mode.PLACE:
		if occupant_id >= 0:
			return select_buildable(occupant_id)
		return _place_selected_type(cell_index)
	if occupant_id >= 0:
		return select_buildable(occupant_id)
	clear_selection()
	return true


func get_mode() -> int:
	return mode


func get_selected_type_id() -> int:
	return selected_type_id


func get_selected_buildable_id() -> int:
	return selected_buildable_id


func get_selected_turret_id() -> int:
	var snapshot: BuildableSnapshot = _grid.get_snapshot(selected_buildable_id)
	if snapshot == null or snapshot.type_id != BuildableType.Id.TURRET:
		return -1
	return selected_buildable_id


func get_hovered_cell_index() -> int:
	return hovered_cell_index


func is_grid_preview_visible() -> bool:
	return (
		mode != Mode.IDLE
		or selected_type_id >= 0
		or selected_buildable_id >= 0
	)


func get_cell_unavailability_reason(cell_index: int) -> StringName:
	if selected_type_id < 0:
		return &""
	if mode == Mode.MOVE and selected_buildable_id >= 0:
		return _grid.get_cell_unavailability_reason(
			selected_type_id,
			cell_index,
			selected_buildable_id
		)
	if mode == Mode.PLACE:
		return _grid.get_place_unavailability_reason(
			selected_type_id,
			cell_index
		)
	return _grid.get_cell_unavailability_reason(
		selected_type_id,
		cell_index,
		selected_buildable_id
	)


func get_hover_reason_text() -> String:
	if hovered_cell_index < 0:
		return "Указатель вне платформы"
	var occupant_id := _grid.get_buildable_id_at_cell(hovered_cell_index)
	if occupant_id >= 0:
		var snapshot: BuildableSnapshot = _grid.get_snapshot(occupant_id)
		if snapshot != null:
			return "Занято: %s" % _get_type_title(snapshot.type_id)
	return get_reason_text(get_cell_unavailability_reason(hovered_cell_index))


func get_reason_text(reason: StringName) -> String:
	match reason:
		&"":
			return "Клетка доступна"
		BuildableGrid.REASON_INVALID_CELL:
			return "Клетка находится вне платформы"
		BuildableGrid.REASON_UNSUPPORTED_TYPE:
			return "Неизвестный тип объекта"
		BuildableGrid.REASON_CELL_NOT_ALLOWED:
			return "Эта клетка не предназначена для выбранного объекта"
		BuildableGrid.REASON_CELL_OCCUPIED:
			return "Клетка уже занята"
		BuildableGrid.REASON_BUILDABLE_LOCKED:
			return "Объект ещё не открыт улучшением"
		BuildableGrid.REASON_DEPLOYMENT_LIMIT:
			return "Достигнут лимит установленных объектов"
	return "Команда недоступна"


func get_feedback_message() -> String:
	return _feedback_message


func is_feedback_error() -> bool:
	return _feedback_is_error


func get_summary() -> String:
	var mode_text := "выбор"
	if mode == Mode.PLACE:
		mode_text = "установка"
	elif mode == Mode.MOVE:
		mode_text = "перенос"
	var selected_text := "ничего"
	if selected_buildable_id >= 0:
		selected_text = "объект %d" % (selected_buildable_id + 1)
	elif selected_type_id >= 0:
		selected_text = _get_type_title(selected_type_id)
	return "%s | %s" % [mode_text, selected_text]


func _place_selected_type(cell_index: int) -> bool:
	var reason := _grid.get_place_unavailability_reason(
		selected_type_id,
		cell_index
	)
	if reason != &"":
		_set_feedback(get_reason_text(reason), true)
		return true
	var buildable_id := _grid.place(selected_type_id, cell_index)
	if buildable_id < 0:
		_set_feedback("Объект не удалось установить", true)
		return true
	select_buildable(buildable_id)
	_set_feedback(
		"Объект установлен в клетку %d" % (cell_index + 1),
		false
	)
	return true


func _move_selected_to(cell_index: int) -> bool:
	var snapshot: BuildableSnapshot = _grid.get_snapshot(selected_buildable_id)
	if snapshot == null:
		clear_selection()
		_set_feedback("Выбранный объект больше не существует", true)
		return true
	var reason := _grid.get_cell_unavailability_reason(
		snapshot.type_id,
		cell_index,
		selected_buildable_id
	)
	if reason != &"":
		_set_feedback(get_reason_text(reason), true)
		return true
	if not _grid.move(selected_buildable_id, cell_index):
		_set_feedback("Объект не удалось перенести", true)
		return true
	_set_mode(Mode.IDLE)
	_set_feedback(
		"Объект мгновенно перенесён в клетку %d; оператор следует к посту" % (
			cell_index + 1
		),
		false
	)
	return true


func _ensure_commands_enabled() -> bool:
	if are_commands_enabled():
		return true
	_set_feedback(_get_blocked_message(), true)
	return false


func _get_blocked_message() -> String:
	match _game_flow.state:
		GameFlowController.RunState.MANUAL_PAUSE:
			return "Размещение заблокировано во время паузы"
		GameFlowController.RunState.CARD_SELECTION:
			return "Размещение заблокировано во время выбора карточки"
		GameFlowController.RunState.START_DELAY:
			return "Размещение станет доступно после начала забега"
		GameFlowController.RunState.GAME_OVER:
			return "Забег завершён"
	return "Команды размещения сейчас недоступны"


func _get_type_title(type_id: int) -> String:
	match type_id:
		BuildableType.Id.MEDICAL_STATION:
			return "Медицинский пост"
		BuildableType.Id.TURRET:
			return "Турель"
	return BuildableType.get_display_name(type_id)


func _set_mode(next_mode: Mode) -> void:
	mode = next_mode
	mode_changed.emit(mode, selected_type_id, selected_buildable_id)


func _set_selected_buildable(buildable_id: int) -> void:
	if selected_buildable_id == buildable_id:
		return
	selected_buildable_id = buildable_id
	selected_buildable_changed.emit(selected_buildable_id)
	selected_turret_changed.emit(get_selected_turret_id())


func _set_feedback(message: String, is_error: bool) -> void:
	_feedback_message = message
	_feedback_is_error = is_error
	feedback_changed.emit(_feedback_message, _feedback_is_error)


func _on_buildable_demolished(
	buildable_id: int,
	_type_id: int,
	_cell_index: int
) -> void:
	if buildable_id != selected_buildable_id:
		return
	selected_type_id = -1
	_set_selected_buildable(-1)
	_set_mode(Mode.IDLE)


func _on_grid_reset() -> void:
	selected_type_id = -1
	hovered_cell_index = -1
	_set_selected_buildable(-1)
	_set_mode(Mode.IDLE)
	hovered_cell_changed.emit(-1)
	_set_feedback("Выберите тип объекта", false)


func _on_run_state_changed(_previous_state: int, new_state: int) -> void:
	if new_state == GameFlowController.RunState.RUNNING:
		return
	if mode != Mode.IDLE:
		_set_mode(Mode.IDLE)
	_set_feedback(_get_blocked_message(), true)
