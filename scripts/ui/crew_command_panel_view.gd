class_name CrewCommandPanelView
extends RefCounted

var _host: Control
var _slot_buttons: Array[Button] = []
var _context_panel: PanelContainer
var _context_box: VBoxContainer
var _feedback_label: Label


func build(host: Control, slot_pressed: Callable) -> void:
	_host = host
	_host.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_host.offset_top = -142.0
	_build_side_panel(true, 0, 6, slot_pressed)
	_build_side_panel(false, 6, 12, slot_pressed)
	_build_context_panel()
	_build_feedback_label()


func update_slot(
	slot_index: int,
	cell_index: int,
	description: Dictionary
) -> void:
	if slot_index < 0 or slot_index >= _slot_buttons.size():
		return
	var button: Button = _slot_buttons[slot_index]
	button.text = "%s\n%s" % [
		description["title"],
		description["occupant"],
	]
	button.disabled = not bool(description["available"])
	button.tooltip_text = "Ячейка платформы %d" % (cell_index + 1)


func show_context(
	description: Dictionary,
	free_ids: Array[int],
	slot_index: int,
	release_pressed: Callable,
	assign_pressed: Callable,
	close_pressed: Callable
) -> void:
	_clear_children(_context_box)
	_context_panel.visible = true
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
		_add_close_button(close_pressed)
		return

	var owner_id: int = int(description["owner"])
	if owner_id >= 0:
		var release := Button.new()
		release.text = "Освободить пост — защитник %d" % (owner_id + 1)
		release.pressed.connect(release_pressed.bind(slot_index))
		_context_box.add_child(release)

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
				assign_pressed.bind(slot_index, defender_id)
			)
			row.add_child(button)
	_add_close_button(close_pressed)


func set_feedback(message: String, is_error: bool) -> void:
	_feedback_label.text = message
	_feedback_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.48, 0.4) if is_error else Color(0.62, 0.92, 0.72)
	)


func close_context() -> void:
	_context_panel.visible = false


func is_context_visible() -> bool:
	return _context_panel != null and _context_panel.visible


func _build_side_panel(
	is_left: bool,
	begin: int,
	end: int,
	slot_pressed: Callable
) -> void:
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
	_host.add_child(panel)

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
		button.pressed.connect(slot_pressed.bind(slot_index))
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
	_host.add_child(_context_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_context_panel.add_child(margin)
	_context_box = VBoxContainer.new()
	_context_box.add_theme_constant_override("separation", 5)
	margin.add_child(_context_box)


func _build_feedback_label() -> void:
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
	_host.add_child(_feedback_label)


func _add_close_button(close_pressed: Callable) -> void:
	var close := Button.new()
	close.text = "Закрыть"
	close.pressed.connect(close_pressed)
	_context_box.add_child(close)


func _clear_children(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


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
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
