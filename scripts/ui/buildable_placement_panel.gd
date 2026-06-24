class_name BuildablePlacementPanel
extends PanelContainer

var _controller: BuildablePlacementController
var _inventory: BuildableInventory
var _grid: BuildableGrid
var _configured: bool = false

var _medical_button: Button
var _turret_button: Button
var _move_button: Button
var _demolish_button: Button
var _cancel_button: Button
var _selection_label: Label
var _cell_label: Label
var _feedback_label: Label


func configure(controller: BuildablePlacementController) -> void:
	_controller = controller
	_inventory = controller.get_node(controller.inventory_path) as BuildableInventory
	_grid = controller.get_node(controller.grid_path) as BuildableGrid
	_configured = true


func _ready() -> void:
	assert(_configured, "BuildablePlacementPanel must be configured")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_left = 0.5
	anchor_top = 1.0
	anchor_right = 0.5
	anchor_bottom = 1.0
	offset_left = -340.0
	offset_top = -152.0
	offset_right = 340.0
	offset_bottom = -16.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	_build_view()
	_connect_signals()
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func get_medical_button() -> Button:
	return _medical_button


func get_turret_button() -> Button:
	return _turret_button


func get_move_button() -> Button:
	return _move_button


func get_demolish_button() -> Button:
	return _demolish_button


func get_cancel_button() -> Button:
	return _cancel_button


func get_selection_text() -> String:
	return _selection_label.text


func get_cell_feedback_text() -> String:
	return _cell_label.text


func _build_view() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 6)
	margin.add_child(root_box)

	var title := Label.new()
	title.text = "РАЗМЕЩЕНИЕ ОБЪЕКТОВ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	root_box.add_child(title)

	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 8)
	root_box.add_child(top_row)

	_medical_button = Button.new()
	_medical_button.name = "MedicalButton"
	_medical_button.custom_minimum_size = Vector2(165.0, 34.0)
	_medical_button.pressed.connect(_on_medical_pressed)
	top_row.add_child(_medical_button)

	_turret_button = Button.new()
	_turret_button.name = "TurretButton"
	_turret_button.custom_minimum_size = Vector2(165.0, 34.0)
	_turret_button.pressed.connect(_on_turret_pressed)
	top_row.add_child(_turret_button)

	_move_button = Button.new()
	_move_button.name = "MoveButton"
	_move_button.text = "Перенести"
	_move_button.pressed.connect(_on_move_pressed)
	top_row.add_child(_move_button)

	_demolish_button = Button.new()
	_demolish_button.name = "DemolishButton"
	_demolish_button.text = "Демонтировать"
	_demolish_button.pressed.connect(_on_demolish_pressed)
	top_row.add_child(_demolish_button)

	_cancel_button = Button.new()
	_cancel_button.name = "CancelButton"
	_cancel_button.text = "Отмена"
	_cancel_button.pressed.connect(_on_cancel_pressed)
	top_row.add_child(_cancel_button)

	_selection_label = Label.new()
	_selection_label.name = "SelectionLabel"
	_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_box.add_child(_selection_label)

	_cell_label = Label.new()
	_cell_label.name = "CellLabel"
	_cell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cell_label.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0))
	root_box.add_child(_cell_label)

	_feedback_label = Label.new()
	_feedback_label.name = "FeedbackLabel"
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_box.add_child(_feedback_label)


func _connect_signals() -> void:
	_controller.mode_changed.connect(_on_controller_changed)
	_controller.hovered_cell_changed.connect(_on_hover_changed)
	_controller.selected_buildable_changed.connect(_on_selected_changed)
	_controller.feedback_changed.connect(_on_feedback_changed)
	_inventory.buildable_unlocked.connect(_on_inventory_changed)
	_inventory.inventory_reset.connect(_on_inventory_reset)
	_grid.buildable_placed.connect(_on_grid_changed)
	_grid.buildable_moved.connect(_on_grid_changed)
	_grid.buildable_demolished.connect(_on_grid_changed)
	_grid.grid_reset.connect(_on_grid_reset)


func _refresh() -> void:
	var medical_unlocked := _inventory.get_unlocked_count(
		BuildableType.Id.MEDICAL_STATION
	)
	var turret_unlocked := _inventory.get_unlocked_count(BuildableType.Id.TURRET)
	var medical_deployed := _grid.get_count_by_type(BuildableType.Id.MEDICAL_STATION)
	var turret_deployed := _grid.get_count_by_type(BuildableType.Id.TURRET)
	_medical_button.text = "Медпост %d/%d" % [medical_deployed, medical_unlocked]
	_turret_button.text = "Турель %d/%d" % [turret_deployed, turret_unlocked]

	var commands_enabled := _controller.are_commands_enabled()
	_medical_button.disabled = not commands_enabled
	_turret_button.disabled = not commands_enabled
	var selected_id := _controller.get_selected_buildable_id()
	_move_button.disabled = not commands_enabled or selected_id < 0
	_demolish_button.disabled = not commands_enabled or selected_id < 0
	_cancel_button.disabled = (
		selected_id < 0
		and _controller.get_mode() == BuildablePlacementController.Mode.IDLE
		and _controller.get_selected_type_id() < 0
	)

	_selection_label.text = _get_selection_text()
	_cell_label.text = _get_cell_text()
	_feedback_label.text = _controller.get_feedback_message()
	var feedback_color := Color(0.66, 0.95, 0.78)
	if _controller.is_feedback_error():
		feedback_color = Color(1.0, 0.46, 0.38)
	_feedback_label.add_theme_color_override("font_color", feedback_color)


func _get_selection_text() -> String:
	var selected_id := _controller.get_selected_buildable_id()
	if selected_id >= 0:
		var snapshot: BuildableSnapshot = _grid.get_snapshot(selected_id)
		if snapshot != null:
			return "Выбран: %s, клетка %d" % [
				_get_type_title(snapshot.type_id),
				snapshot.cell_index + 1,
			]
	var type_id := _controller.get_selected_type_id()
	if type_id >= 0:
		return "Тип: %s" % _get_type_title(type_id)
	return "Объект не выбран"


func _get_cell_text() -> String:
	var cell_index := _controller.get_hovered_cell_index()
	if cell_index < 0:
		return "Наведите указатель на клетку платформы"
	return "Клетка %d — %s" % [
		cell_index + 1,
		_controller.get_hover_reason_text(),
	]


func _get_type_title(type_id: int) -> String:
	if type_id == BuildableType.Id.MEDICAL_STATION:
		return "медицинский пост"
	if type_id == BuildableType.Id.TURRET:
		return "турель"
	return BuildableType.get_display_name(type_id)


func _on_medical_pressed() -> void:
	_controller.begin_placement(BuildableType.Id.MEDICAL_STATION)


func _on_turret_pressed() -> void:
	_controller.begin_placement(BuildableType.Id.TURRET)


func _on_move_pressed() -> void:
	_controller.begin_move_selected()


func _on_demolish_pressed() -> void:
	_controller.demolish_selected()


func _on_cancel_pressed() -> void:
	_controller.clear_selection()


func _on_controller_changed(_mode: int, _type_id: int, _buildable_id: int) -> void:
	_refresh()


func _on_hover_changed(_cell_index: int) -> void:
	_refresh()


func _on_selected_changed(_buildable_id: int) -> void:
	_refresh()


func _on_feedback_changed(_message: String, _is_error: bool) -> void:
	_refresh()


func _on_inventory_changed(_type_id: int, _count: int) -> void:
	_refresh()


func _on_inventory_reset() -> void:
	_refresh()


func _on_grid_changed(_a: int, _b: int, _c: int) -> void:
	_refresh()


func _on_grid_reset() -> void:
	_refresh()
