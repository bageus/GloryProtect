class_name UpgradeSelectionPanel
extends Control

const MODAL_Z_INDEX: int = 100
const CARD_META_GROUP_ID: StringName = &"card_group_id"

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
	if card_index < 0 or card_index >= _cards_container.get_child_count():
		return &""
	var button: Button = _cards_container.get_child(card_index) as Button
	if button == null:
		return &""
	return button.get_meta(CARD_META_GROUP_ID, &"") as StringName


func get_rendered_card_text(card_index: int) -> String:
	if card_index < 0 or card_index >= _cards_container.get_child_count():
		return ""
	var button: Button = _cards_container.get_child(card_index) as Button
	return button.text if button != null else ""


func _on_offer_opened(
	_offer_number: int,
	_cost: int,
	_card_count: int
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
		var definition: UpgradeDefinition = _upgrades.get_card_definition(
			card_index
		)
		if definition == null:
			continue
		var button := Button.new()
		button.name = "Card%s" % String(card_id)
		button.custom_minimum_size = Vector2(300.0, 360.0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = _build_card_text(definition)
		button.disabled = _selection_pending
		button.set_meta(
			CARD_META_GROUP_ID,
			UpgradeCardFormatter.get_card_group_id(definition.card_type)
		)
		_apply_card_style(button, definition.card_type)
		button.pressed.connect(
			_submit_card.bind(card_id, offer_number)
		)
		_cards_container.add_child(button)


func _build_card_text(definition: UpgradeDefinition) -> String:
	var lines := PackedStringArray([
		definition.title,
		"%s %s" % [
			UpgradeCardFormatter.get_card_group_symbol(definition.card_type),
			UpgradeCardFormatter.get_card_group_name(definition.card_type),
		],
		"%s • %s" % [
			UpgradeCardFormatter.get_branch_name(definition.branch_id),
			UpgradeCardFormatter.get_type_name(definition.card_type),
		],
		"Цена: %d" % _upgrades.get_current_cost(),
		"",
		definition.description,
	])
	var effect_text: String = UpgradeCardFormatter.get_effect_summary(
		definition.effect
	)
	if not effect_text.is_empty():
		lines.append("")
		lines.append(effect_text)
	var repeat_text: String = UpgradeCardFormatter.get_repeat_text(
		definition,
		_upgrades.get_runtime()
	)
	if not repeat_text.is_empty():
		lines.append("")
		lines.append(repeat_text)
	return "\n".join(lines)


func _apply_card_style(button: Button, card_type: int) -> void:
	var accent: Color = UpgradeCardFormatter.get_card_group_accent_color(card_type)
	button.add_theme_stylebox_override("normal", _make_card_style(accent, 0.13))
	button.add_theme_stylebox_override("hover", _make_card_style(accent, 0.18))
	button.add_theme_stylebox_override("pressed", _make_card_style(accent, 0.10))
	button.add_theme_stylebox_override("disabled", _make_card_style(accent, 0.07))
	button.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.88, 0.94, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.62, 0.66, 0.72))
	button.add_theme_font_size_override("font_size", 16)


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
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
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
	var lines := PackedStringArray([
		"ДИАГНОСТИКА ДОСТУПНОСТИ",
	])
	for definition: UpgradeDefinition in _upgrades.get_all_card_definitions():
		var reason: StringName = _upgrades.get_card_unavailability_reason(
			definition.card_id
		)
		lines.append("%s — %s" % [
			definition.title,
			UpgradeCardFormatter.get_diagnostic_text(reason),
		])
	_diagnostics_label.text = "\n".join(lines)
