class_name CrewCommandPanelView
extends RefCounted

var defender_group: ButtonGroup = ButtonGroup.new()
var defender_buttons: Dictionary[int, Button] = {}
var role_buttons: Dictionary[int, Button] = {}
var turret_buttons: Dictionary[int, Button] = {}

var selection_label: Label
var defender_row: HBoxContainer
var role_row: HBoxContainer
var turret_row: HBoxContainer
var feedback_label: Label


func build(root: Control) -> void:
	root.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	root.offset_left = 16.0
	root.offset_top = -252.0
	root.offset_right = -16.0
	root.offset_bottom = -16.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

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

	defender_row = HBoxContainer.new()
	defender_row.alignment = BoxContainer.ALIGNMENT_CENTER
	defender_row.add_theme_constant_override("separation", 8)
	content.add_child(defender_row)

	selection_label = Label.new()
	selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(selection_label)

	role_row = HBoxContainer.new()
	role_row.alignment = BoxContainer.ALIGNMENT_CENTER
	role_row.add_theme_constant_override("separation", 6)
	content.add_child(role_row)

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

	turret_row = HBoxContainer.new()
	turret_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turret_row.alignment = BoxContainer.ALIGNMENT_CENTER
	turret_row.add_theme_constant_override("separation", 6)
	turret_scroll.add_child(turret_row)

	feedback_label = Label.new()
	feedback_label.text = "Выберите защитника и назначьте роль"
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_color_override(
		"font_color",
		Color(0.72, 0.8, 0.88)
	)
	content.add_child(feedback_label)


func rebuild_defender_buttons(
	defender_count: int,
	pressed_callback: Callable
) -> void:
	_clear_children(defender_row)
	defender_buttons.clear()
	for defender_id: int in range(defender_count):
		var button := Button.new()
		button.custom_minimum_size = Vector2(154.0, 54.0)
		button.toggle_mode = true
		button.button_group = defender_group
		button.pressed.connect(pressed_callback.bind(defender_id))
		defender_row.add_child(button)
		defender_buttons[defender_id] = button


func rebuild_role_buttons(
	role_ids: Array[int],
	pressed_callback: Callable
) -> void:
	_clear_children(role_row)
	role_buttons.clear()
	for role_id: int in role_ids:
		var button := Button.new()
		button.custom_minimum_size = Vector2(140.0, 40.0)
		button.pressed.connect(pressed_callback.bind(role_id))
		role_row.add_child(button)
		role_buttons[role_id] = button


func rebuild_turret_buttons(
	buildable_ids: Array[int],
	pressed_callback: Callable
) -> void:
	_clear_children(turret_row)
	turret_buttons.clear()
	for buildable_id: int in buildable_ids:
		var button := Button.new()
		button.custom_minimum_size = Vector2(188.0, 40.0)
		button.pressed.connect(pressed_callback.bind(buildable_id))
		turret_row.add_child(button)
		turret_buttons[buildable_id] = button
	if turret_buttons.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Установленных турелей нет"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		turret_row.add_child(empty_label)


func set_feedback(message: String, is_error: bool) -> void:
	feedback_label.text = message
	var color := Color(0.65, 0.9, 0.75)
	if is_error:
		color = Color(1.0, 0.5, 0.42)
	feedback_label.add_theme_color_override("font_color", color)


func _clear_children(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
