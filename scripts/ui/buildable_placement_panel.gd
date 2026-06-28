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
var _title_label: Label
var _status_label: Label
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
	anchor_left = 0.0
	anchor_top = 0.5
	anchor_right = 0.0
	anchor_bottom = 0.5
	offset_left = 16.0
	offset_top = -210.0
	offset_right = 258.0
	offset_bottom = 210.0
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_BOTH
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
	return _title_label.text


func get_cell_feedback_text() -> String:
	return _status_label.text


func _build_view() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 8)
	margin.add_child(root_box)
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", 16)
	root_box.add_child(_title_label)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0))
	root_box.add_child(_status_label)
	_medical_button = _create_action_button("MedicalButton", _on_medical_pressed)
	root_box.add_child(_medical_button)
	_turret_button = _create_action_button("TurretButton", _on_turret_pressed)
	root_box.add_child(_turret_button)
	_move_button = _create_action_button("MoveButton", _on_move_pressed)
	_move_button.text = "Перенести"
	root_box.add_child(_move_button)
	_demolish_button = _create_action_button("DemolishButton", _on_demolish_pressed)
	_demolish_button.text = "Демонтировать"
	root_box.add_child(_demolish_button)
	_cancel_button = _create_action_button("CancelButton", _on_cancel_pressed)
	_cancel_button.text = "Отмена"
	root_box.add_child(_cancel_button)
	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_box.add_child(_feedback_label)


func _create_action_button(button_name: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = button_name
	button.custom_minimum_size = Vector2(210.0, 38.0)
	button.pressed.connect(callback)
	return button


func _connect_signals() -> void:
	_controller.mode_changed.connect(_on_controller_changed)
	_controller.hovered_cell_changed.connect(_on_hover_changed)
	_controller.selected_cell_changed.connect(_on_selected_cell_changed)
	_controller.selected_buildable_changed.connect(_on_selected_changed)
	_controller.feedback_changed.connect(_on_feedback_changed)
	_inventory.buildable_unlocked.connect(_on_inventory_changed)
	_inventory.inventory_reset.connect(_on_inventory_reset)
	_grid.buildable_placed.connect(_on_grid_changed)
	_grid.buildable_moved.connect(_on_grid_changed)
	_grid.buildable_demolished.connect(_on_grid_changed)
	_grid.grid_reset.connect(_on_grid_reset)


func _refresh() -> void:
	visible = _controller.has_cell_context() or _controller.get_mode() != BuildablePlacementController.Mode.IDLE
	if not visible:
		return
	var commands_enabled: bool = _controller.are_commands_enabled()
	var selected_id: int = _controller.get_selected_buildable_id()
	var selected_cell: int = _controller.get_selected_cell_index()
	var mode: int = _controller.get_mode()
	var has_object: bool = selected_id >= 0
	var has_empty_cell: bool = selected_cell >= 0 and not has_object
	var snapshot: BuildableSnapshot = _grid.get_snapshot(selected_id)
	var medical_placeable: bool = (
		mode == BuildablePlacementController.Mode.IDLE
		and has_empty_cell
		and commands_enabled
		and _controller.can_place_type_in_selected_cell(
			BuildableType.Id.MEDICAL_STATION
		)
	)
	var turret_placeable: bool = (
		mode == BuildablePlacementController.Mode.IDLE
		and has_empty_cell
		and commands_enabled
		and _controller.can_place_type_in_selected_cell(BuildableType.Id.TURRET)
	)
	_medical_button.visible = medical_placeable
	_turret_button.visible = turret_placeable
	_move_button.visible = (
		has_object
		and snapshot != null
		and snapshot.type_id != BuildableType.Id.MEDICAL_STATION
	)
	_demolish_button.visible = has_object
	_cancel_button.visible = true
	var medical_deployed: int = _grid.get_count_by_type(BuildableType.Id.MEDICAL_STATION)
	var medical_unlocked: int = _inventory.get_unlocked_count(BuildableType.Id.MEDICAL_STATION)
	var turret_deployed: int = _grid.get_count_by_type(BuildableType.Id.TURRET)
	var turret_unlocked: int = _inventory.get_unlocked_count(BuildableType.Id.TURRET)
	_medical_button.text = "Медпост %d/%d" % [medical_deployed, medical_unlocked]
	_turret_button.text = "Турель %d/%d" % [turret_deployed, turret_unlocked]
	_medical_button.disabled = false
	_turret_button.disabled = false
	_move_button.disabled = not commands_enabled or not _move_button.visible
	_demolish_button.disabled = not commands_enabled or not has_object
	_cancel_button.disabled = false
	var context_cell: int = _get_context_cell_index()
	_title_label.text = _get_cell_title(context_cell)
	_status_label.text = _get_cell_status(context_cell)
	_feedback_label.text = _controller.get_feedback_message()
	var feedback_color := Color(0.66, 0.95, 0.78)
	if _controller.is_feedback_error():
		feedback_color = Color(1.0, 0.46, 0.38)
	_feedback_label.add_theme_color_override("font_color", feedback_color)


func _get_context_cell_index() -> int:
	if _controller.get_mode() != BuildablePlacementController.Mode.IDLE:
		var hovered_cell: int = _controller.get_hovered_cell_index()
		if hovered_cell >= 0:
			return hovered_cell
	return _controller.get_selected_cell_index()


func _get_cell_title(cell_index: int) -> String:
	if cell_index < 0:
		return "Ячейка не выбрана"
	return "Ячейка %d" % (cell_index + 1)


func _get_cell_status(cell_index: int) -> String:
	if cell_index < 0:
		return ""
	var occupant_id: int = _grid.get_buildable_id_at_cell(cell_index)
	if occupant_id < 0:
		return "Пустая"
	var snapshot: BuildableSnapshot = _grid.get_snapshot(occupant_id)
	if snapshot == null:
		return "Пустая"
	return _get_type_title(snapshot.type_id)


func _get_type_title(type_id: int) -> String:
	if type_id == BuildableType.Id.MEDICAL_STATION:
		return "Медицинский пост"
	if type_id == BuildableType.Id.TURRET:
		return "Турель"
	return BuildableType.get_display_name(type_id)


func _on_medical_pressed() -> void:
	if not _controller.place_type_in_selected_cell(BuildableType.Id.MEDICAL_STATION):
		_controller.begin_placement(BuildableType.Id.MEDICAL_STATION)


func _on_turret_pressed() -> void:
	if not _controller.place_type_in_selected_cell(BuildableType.Id.TURRET):
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


func _on_selected_cell_changed(_cell_index: int) -> void:
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
