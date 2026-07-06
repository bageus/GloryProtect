class_name UpgradeSelectionPanel
extends Control

const MODAL_Z_INDEX: int = 100
const CARD_WIDTH: float = 300.0
const CARD_HEIGHT: float = 384.0
const CARD_HORIZONTAL_MARGIN: float = 14.0
const CARD_TEXT_MIN_WIDTH: float = CARD_WIDTH - CARD_HORIZONTAL_MARGIN * 2.0
const PRICE_PANEL_HEIGHT: float = 46.0
const CARD_META_GROUP_ID: StringName = &"card_group_id"
const CARD_META_PRICE_LABEL: StringName = &"price_label"
const CARD_META_PRICE_PANEL: StringName = &"price_panel"
const CARD_META_TYPE_LABEL: StringName = &"type_label"
const CARD_META_DEPENDENCY_PREVIEW_LABEL: StringName = &"dependency_preview_label"

@export_node_path("UpgradeSystem") var upgrade_system_path: NodePath

var _selection_pending: bool = false
var _diagnostics_visible: bool = false

@onready var _upgrades: UpgradeSystem = get_node(upgrade_system_path)
@onready var _offer_label: Label = %OfferLabel
@onready var _mode_label: Label = %ModeLabel
@onready var _cost_label: Label = %CostLabel
@onready var _cards_container: HBoxContainer = %CardsContainer
@onready var _diagnostics_label: Label = %DiagnosticsLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_as_relative = false
	z_index = MODAL_Z_INDEX
	visible = false
	_cost_label.visible = false
	_upgrades.offer_opened.connect(_on_offer_opened)
	_upgrades.offer_closed.connect(_on_offer_closed)
	_upgrades.progress_reset.connect(_on_progress_reset)
	if _upgrades.is_offer_open():
		_show_current_offer()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_F9:
		_diagnostics_visible = not _diagnostics_visible
		_rebuild_card_buttons()
		_refresh_diagnostics()
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode < KEY_1 or key_event.keycode > KEY_3:
		return
	var card_index: int = key_event.keycode - KEY_1
	if card_index >= _upgrades.get_card_count():
		return
	_submit_card(
		_upgrades.get_card_id(card_index),
		_upgrades.get_current_offer_number()
	)
	get_viewport().set_input_as_handled()


func is_selection_pending() -> bool:
	return _selection_pending


func is_diagnostics_visible() -> bool:
	return _diagnostics_visible


func show_diagnostics_for_tests() -> void:
	_diagnostics_visible = true
	_rebuild_card_buttons()
	_refresh_diagnostics()


func get_diagnostics_text_for_tests() -> String:
	return _diagnostics_label.text


func get_dependency_preview_text_for_tests(card_id: StringName) -> String:
	return _build_dependency_preview_text(_upgrades.catalog.get_definition(card_id))


func get_rendered_card_count() -> int:
	return _cards_container.get_child_count()


func get_offer_text() -> String:
	return _offer_label.text


func get_mode_text() -> String:
	return _mode_label.text


func get_cost_text() -> String:
	return _cost_label.text


func is_global_cost_visible() -> bool:
	return _cost_label.visible


func get_rendered_card_group_id(card_index: int) -> StringName:
	var button: Button = _get_card_button(card_index)
	if button == null:
		return &""
	return button.get_meta(CARD_META_GROUP_ID, &"") as StringName


func get_rendered_card_text(card_index: int) -> String:
	var button: Button = _get_card_button(card_index)
	if button == null:
		return ""
	var lines := PackedStringArray()
	_collect_label_texts(button, lines)
	return "\n".join(lines)


func get_rendered_card_type_text(card_index: int) -> String:
	var label: Label = _get_card_meta_label(card_index, CARD_META_TYPE_LABEL)
	return "" if label == null else label.text


func get_rendered_card_price_text(card_index: int) -> String:
	var label: Label = _get_card_meta_label(card_index, CARD_META_PRICE_LABEL)
	return "" if label == null else label.text


func get_rendered_card_dependency_preview_text(card_index: int) -> String:
	var label: Label = _get_card_meta_label(
		card_index,
		CARD_META_DEPENDENCY_PREVIEW_LABEL
	)
	return "" if label == null else label.text


func get_rendered_card_price_color(card_index: int) -> Color:
	var label: Label = _get_card_meta_label(card_index, CARD_META_PRICE_LABEL)
	if label == null:
		return Color.TRANSPARENT
	return label.get_theme_color("font_color")


func get_rendered_card_price_global_y(card_index: int) -> float:
	var panel: Control = _get_card_meta_control(card_index, CARD_META_PRICE_PANEL)
	return INF if panel == null else panel.get_global_rect().position.y


func has_rendered_card_label(card_index: int, label_name: String) -> bool:
	var button: Button = _get_card_button(card_index)
	return button != null and _find_child_by_name(button, label_name) != null


func _on_offer_opened(
	_offer_number: int,
	_cost: int,	_card_count: int
) -> void:
	_selection_pending = false
	_show_current_offer()


func _on_offer_closed() -> void:
	_selection_pending = false
	visible = false


func _on_progress_reset() -> void:
	_selection_pending = false
	visible = false


func _show_current_offer() -> void:
	z_index = MODAL_Z_INDEX
	visible = true
	_offer_label.text = "Уровень %d" % _upgrades.get_current_offer_number()
	_cost_label.text = ""
	_cost_label.visible = false
	if _upgrades.is_specialization_offer():
		_mode_label.text = "СПЕЦИАЛИЗАЦИЯ — %s" % (
			UpgradeCardFormatter.get_branch_name(
				_upgrades.get_specialization_offer_branch()
			)
		)
	else:
		_mode_label.text = "УЛУЧШЕНИЯ"
	_rebuild_card_buttons()
	_refresh_diagnostics()


func _rebuild_card_buttons() -> void:
	for child: Node in _cards_container.get_children():
		_cards_container.remove_child(child)
		child.queue_free()

	var offer_number: int = _upgrades.get_current_offer_number()
	for card_index: int in range(_upgrades.get_card_count()):
		var card_id: StringName = _upgrades.get_card_id(card_index)
		var definition: UpgradeDefinition = _upgrades.get_card_definition(card_index)
		if definition == null:
			continue
		var button := Button.new()
		button.name = "Card%s" % String(card_id)
		button.text = ""
		button.clip_contents = true
		button.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
		button.disabled = _selection_pending
		button.set_meta(
			CARD_META_GROUP_ID,
			UpgradeCardFormatter.get_card_group_id(definition.card_type)
		)
		_apply_card_style(button, definition.card_type)
		_build_card_content(button, definition)
		button.pressed.connect(_submit_card.bind(card_id, offer_number))
		_cards_container.add_child(button)


func _build_card_content(button: Button, definition: UpgradeDefinition) -> void:
	var accent: Color = UpgradeCardFormatter.get_card_group_accent_color(
		definition.card_type
	)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(CARD_HORIZONTAL_MARGIN))
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", int(CARD_HORIZONTAL_MARGIN))
	margin.add_theme_constant_override("margin_bottom", 16)
	button.add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(CARD_TEXT_MIN_WIDTH, 0.0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 9)
	margin.add_child(box)

	var type_label := _make_card_label(
		"TypeLabel",
		"%s %s" % [
			UpgradeCardFormatter.get_card_group_symbol(definition.card_type),
			UpgradeCardFormatter.get_card_group_name(definition.card_type),
		],
		15,
		accent.lightened(0.18),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	button.set_meta(CARD_META_TYPE_LABEL, type_label)
	box.add_child(type_label)

	var center := CenterContainer.new()
	center.name = "ContentCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(center)

	var content_box := VBoxContainer.new()
	content_box.name = "MainContent"
	content_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_box.custom_minimum_size = Vector2(CARD_TEXT_MIN_WIDTH, 0.0)
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.alignment = BoxContainer.ALIGNMENT_CENTER
	content_box.add_theme_constant_override("separation", 10)
	center.add_child(content_box)

	content_box.add_child(_make_card_label(
		"TitleLabel",
		definition.title,
		19,
		Color(0.96, 0.99, 1.0),
		HORIZONTAL_ALIGNMENT_CENTER
	))
	content_box.add_child(_make_card_label(
		"DescriptionLabel",
		definition.description,
		15,
		Color(0.9, 0.94, 0.98),
		HORIZONTAL_ALIGNMENT_CENTER
	))
	var effect_summary: String = UpgradeCardFormatter.get_effect_summary(definition.effect)
	if not effect_summary.is_empty() and effect_summary != "Без немедленного эффекта":
		content_box.add_child(_make_card_label(
			"EffectSummaryLabel",
			effect_summary,
			16,
			accent.lightened(0.28),
			HORIZONTAL_ALIGNMENT_CENTER
		))
	var repeat_text: String = UpgradeCardFormatter.get_repeat_text(
		definition,
		_upgrades.get_runtime()
	)
	if not repeat_text.is_empty():
		content_box.add_child(_make_card_label(
			"RepeatLabel",
			repeat_text,
			14,
			Color(0.74, 0.82, 0.92),
			HORIZONTAL_ALIGNMENT_CENTER
		))
	if _diagnostics_visible:
		var dependency_text: String = _build_dependency_preview_text(definition)
		if not dependency_text.is_empty():
			var dependency_label := _make_card_label(
				"DependencyPreviewLabel",
				dependency_text,
				12,
				Color(0.52, 0.58, 0.68, 0.82),
				HORIZONTAL_ALIGNMENT_LEFT
			)
			button.set_meta(CARD_META_DEPENDENCY_PREVIEW_LABEL, dependency_label)
			content_box.add_child(dependency_label)

	var price_panel := PanelContainer.new()
	price_panel.name = "PricePanel"
	price_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	price_panel.custom_minimum_size = Vector2(0.0, PRICE_PANEL_HEIGHT)
	price_panel.add_theme_stylebox_override("panel", _make_price_style())
	button.set_meta(CARD_META_PRICE_PANEL, price_panel)
	var price_label := _make_card_label(
		"PriceLabel",
		"Цена: %d" % _upgrades.get_current_cost(),
		18,
		UpgradeCardFormatter.get_price_color(),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	price_label.custom_minimum_size = Vector2.ZERO
	price_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.set_meta(CARD_META_PRICE_LABEL, price_label)
	price_panel.add_child(price_label)
	box.add_child(price_panel)


func _make_card_label(
	label_name: String,
	text: String,
	font_size: int,
	font_color: Color,
	alignment: HorizontalAlignment
) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(CARD_TEXT_MIN_WIDTH, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	return label


func _apply_card_style(button: Button, card_type: int) -> void:
	var accent: Color = UpgradeCardFormatter.get_card_group_accent_color(card_type)
	button.add_theme_stylebox_override("normal", _make_card_style(accent, 0.13))
	button.add_theme_stylebox_override("hover", _make_card_style(accent, 0.18))
	button.add_theme_stylebox_override("pressed", _make_card_style(accent, 0.10))
	button.add_theme_stylebox_override("disabled", _make_card_style(accent, 0.07))
	button.add_theme_color_override("font_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_disabled_color", Color.TRANSPARENT)
	button.add_theme_font_size_override("font_size", 1)


func _make_card_style(accent: Color, tint: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(
		clampf(accent.r * tint, 0.0, 1.0),
		clampf(accent.g * tint, 0.0, 1.0),
		clampf(accent.b * tint, 0.0, 1.0),
		0.97
	)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.96)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0.0, 3.0)
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style


func _make_price_style() -> StyleBoxFlat:
	var price_color: Color = UpgradeCardFormatter.get_price_color()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(price_color.r, price_color.g, price_color.b, 0.12)
	style.border_color = Color(price_color.r, price_color.g, price_color.b, 0.82)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func _submit_card(
	card_id: StringName,
	offer_number: int
) -> void:
	if _selection_pending or card_id == &"":
		return
	_selection_pending = true
	_set_buttons_disabled(true)
	var accepted: bool = _upgrades.choose_card_for_offer(
		card_id,
		offer_number
	)
	if accepted:
		return
	_selection_pending = false
	_set_buttons_disabled(false)
	_refresh_diagnostics()


func _set_buttons_disabled(disabled: bool) -> void:
	for child: Node in _cards_container.get_children():
		var button: Button = child as Button
		if button != null:
			button.disabled = disabled


func _refresh_diagnostics() -> void:
	_diagnostics_label.visible = _diagnostics_visible
	if not _diagnostics_visible:
		return
	_diagnostics_label.text = UpgradeDiagnosticsTreeFormatter.build(_upgrades)


func _build_dependency_preview_text(definition: UpgradeDefinition) -> String:
	if definition == null:
		return ""
	var child_definitions: Array[UpgradeDefinition] = _get_direct_child_definitions(
		definition.card_id
	)
	var lines := PackedStringArray()
	if not child_definitions.is_empty():
		for child_definition: UpgradeDefinition in child_definitions:
			lines.append("   └─ ○ %s" % child_definition.title)
		return "\n".join(lines)
	if not definition.prerequisite_card_ids.is_empty():
		return "Требуется выше: %s" % _join_card_titles(
			definition.prerequisite_card_ids
		)
	if definition.required_repeat_card_id != &"":
		return "Требуется выше: %s ×%d" % [
			_get_card_title(definition.required_repeat_card_id),
			definition.required_repeat_count,
		]
	if definition.required_specialization_id != &"":
		return "Требуется специализация: %s" % _get_card_title(
			definition.required_specialization_id
		)
	return ""


func _get_direct_child_definitions(card_id: StringName) -> Array[UpgradeDefinition]:
	var result: Array[UpgradeDefinition] = []
	if card_id == &"":
		return result
	for definition: UpgradeDefinition in _upgrades.get_all_card_definitions():
		if definition == null:
			continue
		if card_id in definition.prerequisite_card_ids:
			result.append(definition)
			continue
		if definition.required_repeat_card_id == card_id:
			result.append(definition)
			continue
		if definition.required_specialization_id == card_id:
			result.append(definition)
	return result


func _join_card_titles(card_ids: Array[StringName]) -> String:
	var titles := PackedStringArray()
	for card_id: StringName in card_ids:
		titles.append(_get_card_title(card_id))
	return ", ".join(titles)


func _get_card_title(card_id: StringName) -> String:
	var definition: UpgradeDefinition = _upgrades.catalog.get_definition(card_id)
	return definition.title if definition != null else String(card_id)


func _get_card_button(card_index: int) -> Button:
	if card_index < 0 or card_index >= _cards_container.get_child_count():
		return null
	return _cards_container.get_child(card_index) as Button


func _get_card_meta_label(card_index: int, meta_key: StringName) -> Label:
	var button: Button = _get_card_button(card_index)
	if button == null:
		return null
	return button.get_meta(meta_key, null) as Label


func _get_card_meta_control(card_index: int, meta_key: StringName) -> Control:
	var button: Button = _get_card_button(card_index)
	if button == null:
		return null
	return button.get_meta(meta_key, null) as Control


func _collect_label_texts(node: Node, lines: PackedStringArray) -> void:
	var label: Label = node as Label
	if label != null and not label.text.is_empty():
		lines.append(label.text)
	for child: Node in node.get_children():
		_collect_label_texts(child, lines)


func _find_child_by_name(node: Node, child_name: String) -> Node:
	if node.name == child_name:
		return node
	for child: Node in node.get_children():
		var found: Node = _find_child_by_name(child, child_name)
		if found != null:
			return found
	return null
