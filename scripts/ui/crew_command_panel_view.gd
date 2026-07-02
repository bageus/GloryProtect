class_name CrewCommandPanelView
extends RefCounted

const NORMAL_CONTEXT_HEIGHT: float = 182.0
const DEFENDER_CONTEXT_HEIGHT: float = 480.0
const BUILDABLE_CONTEXT_HEIGHT: float = 320.0
const CONTEXT_BOTTOM_OFFSET: float = -148.0
const CONTEXT_TOP_MARGIN: float = 12.0
const CONTEXT_HALF_WIDTH: float = 210.0
const CONTEXT_LEFT_SHIFT: float = -260.0
const CONTEXT_EDGE_MARGIN: float = 12.0
const CONTEXT_BACKGROUND_ALPHA: float = 0.78

var _host: Control
var _slot_buttons: Array[Button] = []
var _context_panel: PanelContainer
var _context_scroll: ScrollContainer
var _context_box: VBoxContainer
var _feedback_label: Label
var _requested_context_height: float = NORMAL_CONTEXT_HEIGHT
var _current_context_center_offset_x: float = 0.0


func build(
	host: Control,
	left_slot_count: int,
	total_slot_count: int,
	slot_pressed: Callable
) -> void:
	_host = host
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _host.resized.is_connected(_fit_context_panel):
		_host.resized.connect(_fit_context_panel)
	_build_side_panel(true, 0, left_slot_count, slot_pressed)
	_build_side_panel(false, left_slot_count, total_slot_count, slot_pressed)
	_build_context_panel()
	_build_feedback_label()


func update_slot(
	slot_index: int,
	spec: Dictionary,
	description: Dictionary
) -> void:
	var button: Button = _slot_buttons[slot_index]
	button.text = "%s\n%s" % [
		description["title"],
		description["occupant"],
	]
	button.disabled = not bool(description["available"])
	button.tooltip_text = "Ячейка платформы %d" % (int(spec["cell"]) + 1)


func rebuild_context(
	description: Dictionary,
	free_ids: Array[int],
	slot_index: int,
	release_pressed: Callable,
	assign_pressed: Callable,
	close_pressed: Callable
) -> void:
	_prepare_context(NORMAL_CONTEXT_HEIGHT)
	_add_context_title(String(description["title"]))
	if not bool(description["available"]):
		_add_centered_label("Пост появится после получения улучшения")
		_add_close_button(close_pressed)
		return
	var owner_id: int = int(description["owner"])
	if owner_id >= 0:
		var release := _make_context_button(
			"Освободить пост — защитник %d" % (owner_id + 1)
		)
		release.pressed.connect(release_pressed.bind(slot_index))
		_context_box.add_child(release)
	if free_ids.is_empty():
		_add_centered_label("Свободных защитников нет")
	else:
		_add_assignment_buttons(free_ids, slot_index, assign_pressed)
	_add_close_button(close_pressed)


func rebuild_defender_type_context(
	defender_id: int,	current_role: int,
	shooter_unlocked: bool,
	type_pressed: Callable,
	close_pressed: Callable
) -> void:
	_prepare_context(NORMAL_CONTEXT_HEIGHT)
	_add_context_title("Защитник %d — тип" % (defender_id + 1))
	_add_type_buttons(
		defender_id,
		current_role,
		shooter_unlocked,
		type_pressed
	)
	_add_close_button(close_pressed)


func rebuild_defender_command_context(
	defender_id: int,
	current_combat_role: int,
	shooter_unlocked: bool,
	post_options: Array[Dictionary],
	type_pressed: Callable,
	post_pressed: Callable,
	free_pressed: Callable,
	close_pressed: Callable
) -> void:
	_prepare_context(DEFENDER_CONTEXT_HEIGHT)
	_add_context_title("Защитник %d" % (defender_id + 1))
	_add_section_label("ТИП БОЙЦА")
	_add_type_buttons(
		defender_id,
		current_combat_role,
		shooter_unlocked,
		type_pressed
	)
	_add_section_label("НАЗНАЧЕНИЕ")
	var free_button := _make_context_button("Свободная боевая ячейка")
	free_button.pressed.connect(free_pressed.bind(defender_id))
	_context_box.add_child(free_button)
	if post_options.is_empty():
		_add_centered_label("Доступных постов нет")
	else:
		for option: Dictionary in post_options:
			var button := _make_context_button(String(option["title"]))
			var owner_id: int = int(option.get("owner", -1))
			var is_current: bool = bool(option.get("current", false))
			if is_current:
				button.text += " — текущий"
			elif owner_id >= 0:
				button.text += " — занят бойцом %d" % (owner_id + 1)
			button.disabled = is_current
			button.pressed.connect(
				post_pressed.bind(defender_id, int(option["slot"]))
			)
			_context_box.add_child(button)
	_add_close_button(close_pressed)


func rebuild_buildable_context(
	title: String,
	status: String,
	actions: Array[Dictionary],
	feedback: String,
	feedback_is_error: bool,
	close_pressed: Callable
) -> void:
	_prepare_context(BUILDABLE_CONTEXT_HEIGHT)
	_add_context_title(title)
	if not status.is_empty():
		_add_centered_label(status)
	for action: Dictionary in actions:
		var button := _make_context_button(String(action["text"]))
		button.disabled = bool(action.get("disabled", false))
		var callback: Callable = action["callback"]
		button.pressed.connect(callback)
		_context_box.add_child(button)
	if not feedback.is_empty():
		var feedback_label := _make_context_label(feedback, HORIZONTAL_ALIGNMENT_CENTER)
		feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		feedback_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.48, 0.4) if feedback_is_error else Color(0.62, 0.92, 0.72)
		)
		_context_box.add_child(feedback_label)
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
	return _context_panel.visible


func get_context_button_texts() -> PackedStringArray:
	var result := PackedStringArray()
	_collect_context_button_texts(_context_box, result)
	return result


func get_context_rect() -> Rect2:
	return _context_panel.get_rect()


func get_context_center_offset_x() -> float:
	return _current_context_center_offset_x


func get_context_background_alpha() -> float:
	var style: StyleBoxFlat = _context_panel.get_theme_stylebox("panel") as StyleBoxFlat
	return 0.0 if style == null else style.bg_color.a


func get_enabled_context_button_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	_collect_enabled_button_rects(_context_box, result)
	return result


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
		panel.offset_left = 0.0
		panel.offset_right = -96.0
	else:
		panel.anchor_left = 0.5
		panel.anchor_right = 1.0
		panel.offset_left = 96.0
		panel.offset_right = 0.0
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
		var button := _make_context_button("")
		button.custom_minimum_size = Vector2(56.0, 92.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(slot_pressed.bind(slot_index))
		row.add_child(button)
		_slot_buttons.append(button)


func _build_context_panel() -> void:
	_context_panel = PanelContainer.new()
	_context_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_context_panel.offset_bottom = CONTEXT_BOTTOM_OFFSET
	_context_panel.add_theme_stylebox_override("panel", _make_context_style())
	_context_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_context_panel.visible = false
	_host.add_child(_context_panel)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_context_panel.add_child(margin)
	_context_scroll = ScrollContainer.new()
	_context_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_context_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_context_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_context_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_context_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_context_scroll)
	_context_box = VBoxContainer.new()
	_context_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_context_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_context_box.add_theme_constant_override("separation", 5)
	_context_scroll.add_child(_context_box)
	_fit_context_panel()


func _build_feedback_label() -> void:
	_feedback_label = Label.new()
	_feedback_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_feedback_label.offset_left = 210.0
	_feedback_label.offset_top = -141.0
	_feedback_label.offset_right = -210.0
	_feedback_label.offset_bottom = -118.0
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 13)
	_feedback_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92))
	_feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.add_child(_feedback_label)


func _prepare_context(requested_height: float) -> void:
	_clear_children(_context_box)
	_requested_context_height = requested_height
	_fit_context_panel()
	_context_scroll.scroll_vertical = 0
	_context_panel.visible = true


func _fit_context_panel() -> void:
	if _host == null or _context_panel == null:
		return
	var host_size: Vector2 = _host.size
	var available_height: float = _requested_context_height
	if host_size.y > 0.0:
		available_height = maxf(
			160.0,
			host_size.y + CONTEXT_BOTTOM_OFFSET - CONTEXT_TOP_MARGIN
		)
	var panel_height: float = minf(_requested_context_height, available_height)
	var half_width: float = CONTEXT_HALF_WIDTH
	if host_size.x > 0.0:
		half_width = minf(
			CONTEXT_HALF_WIDTH,
			maxf(140.0, host_size.x * 0.5 - CONTEXT_EDGE_MARGIN)
		)
	var center_offset: float = CONTEXT_LEFT_SHIFT
	if host_size.x > 0.0:
		var maximum_offset: float = maxf(
			0.0,
			host_size.x * 0.5 - half_width - CONTEXT_EDGE_MARGIN
		)
		center_offset = clampf(
			CONTEXT_LEFT_SHIFT,
			-maximum_offset,
			maximum_offset
		)
	_current_context_center_offset_x = center_offset
	_context_panel.offset_left = center_offset - half_width
	_context_panel.offset_right = center_offset + half_width
	_context_panel.offset_bottom = CONTEXT_BOTTOM_OFFSET
	_context_panel.offset_top = CONTEXT_BOTTOM_OFFSET - panel_height


func _add_context_title(text: String) -> void:
	var title := _make_context_label(text, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_font_size_override("font_size", 17)
	_context_box.add_child(title)


func _add_section_label(text: String) -> void:
	var label := _make_context_label(text, HORIZONTAL_ALIGNMENT_CENTER)
	label.add_theme_color_override("font_color", Color(0.68, 0.82, 1.0))
	label.add_theme_font_size_override("font_size", 13)
	_context_box.add_child(label)


func _add_type_buttons(
	defender_id: int,
	current_role: int,
	shooter_unlocked: bool,
	type_pressed: Callable
) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	_context_box.add_child(row)
	var melee := _make_context_button("Боец")
	melee.disabled = current_role == CrewRole.Id.FREE_FIGHTER
	melee.pressed.connect(
		type_pressed.bind(defender_id, CrewRole.Id.FREE_FIGHTER)
	)
	row.add_child(melee)
	var shooter := _make_context_button("Стрелок")
	shooter.disabled = (
		not shooter_unlocked or current_role == CrewRole.Id.SHOOTER
	)
	shooter.tooltip_text = (
		""
		if shooter_unlocked
		else "Тип «Стрелок» ещё не открыт"
	)
	shooter.pressed.connect(
		type_pressed.bind(defender_id, CrewRole.Id.SHOOTER)
	)
	row.add_child(shooter)


func _add_centered_label(text: String) -> void:
	_context_box.add_child(_make_context_label(text, HORIZONTAL_ALIGNMENT_CENTER))


func _add_assignment_buttons(
	free_ids: Array[int],
	slot_index: int,
	assign_pressed: Callable
) -> void:
	_context_box.add_child(_make_context_label(
		"Назначить свободного защитника:",
		HORIZONTAL_ALIGNMENT_LEFT
	))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	_context_box.add_child(row)
	for defender_id: int in free_ids:
		var button := _make_context_button("Защитник %d" % (defender_id + 1))
		button.pressed.connect(assign_pressed.bind(slot_index, defender_id))
		row.add_child(button)


func _add_close_button(close_pressed: Callable) -> void:
	var close := _make_context_button("Закрыть")
	close.pressed.connect(close_pressed)
	_context_box.add_child(close)


func _make_context_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	return button


func _make_context_label(text: String, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _clear_children(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.055, 0.86)
	style.border_color = Color(0.2, 0.34, 0.48, 0.9)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


func _make_context_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.026, 0.043, CONTEXT_BACKGROUND_ALPHA)
	style.border_color = Color(0.34, 0.56, 0.76, 0.88)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _collect_context_button_texts(node: Node, result: PackedStringArray) -> void:
	var button: Button = node as Button
	if button != null:
		result.append(button.text)
	for child: Node in node.get_children():
		_collect_context_button_texts(child, result)


func _collect_enabled_button_rects(node: Node, result: Array[Rect2]) -> void:
	var button: Button = node as Button
	if button != null and button.visible and not button.disabled:
		result.append(button.get_global_rect())
	for child: Node in node.get_children():
		_collect_enabled_button_rects(child, result)
