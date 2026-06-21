class_name UpgradeSelectionPanel
extends Control

@export_node_path("UpgradeSystem") var upgrade_system_path: NodePath

var _builder := UpgradePresentationBuilder.new()
var _card_buttons: Array[Button] = []
var _selection_locked: bool = false
var _displayed_offer_number: int = 0

@onready var _upgrades: UpgradeSystem = get_node(upgrade_system_path)
@onready var _offer_label: Label = %OfferLabel
@onready var _cost_label: Label = %CostLabel
@onready var _specialization_label: Label = %SpecializationLabel
@onready var _cards_container: HBoxContainer = %CardsContainer
@onready var _diagnostics_toggle: CheckButton = %DiagnosticsToggle
@onready var _diagnostics_label: RichTextLabel = %DiagnosticsLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_builder.configure(_upgrades.catalog, _upgrades.get_runtime())
	_upgrades.offer_opened.connect(_on_offer_opened)
	_upgrades.offer_closed.connect(_on_offer_closed)
	_upgrades.progress_reset.connect(_on_progress_reset)
	_diagnostics_toggle.toggled.connect(_on_diagnostics_toggled)
	if _upgrades.is_offer_open():
		_show_current_offer()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _selection_locked or not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode < KEY_1 or key_event.keycode > KEY_3:
		return
	var card_index: int = key_event.keycode - KEY_1
	if card_index >= _upgrades.get_card_count():
		return
	var card_id: StringName = _upgrades.get_card_id(card_index)
	if _submit_card(card_id, _displayed_offer_number):
		get_viewport().set_input_as_handled()


func _on_offer_opened(
	_offer_number: int,
	_cost: int,
	_card_count: int
) -> void:
	_show_current_offer()


func _on_offer_closed() -> void:
	visible = false
	_selection_locked = false
	_card_buttons.clear()


func _on_progress_reset() -> void:
	visible = false
	_selection_locked = false
	_card_buttons.clear()


func _show_current_offer() -> void:
	visible = true
	_selection_locked = false
	_displayed_offer_number = _upgrades.get_current_offer_number()
	_offer_label.text = (
		"СОБЫТИЕ СПЕЦИАЛИЗАЦИИ"
		if _upgrades.is_specialization_offer()
		else "ВЫБЕРИТЕ КАРТОЧКУ"
	)
	_offer_label.text += " — ВЫДАЧА %d" % _displayed_offer_number
	_cost_label.text = "Стоимость: %d монет" % _upgrades.get_current_cost()
	_specialization_label.visible = _upgrades.is_specialization_offer()
	if _specialization_label.visible:
		_specialization_label.text = "Ветка: %s — выбор заблокирует две альтернативы" % (
			_builder.get_branch_label(_upgrades.get_specialization_offer_branch())
		)
	_rebuild_card_buttons()
	_refresh_diagnostics()


func _rebuild_card_buttons() -> void:
	_card_buttons.clear()
	for child: Node in _cards_container.get_children():
		_cards_container.remove_child(child)
		child.queue_free()

	for card_index: int in range(_upgrades.get_card_count()):
		var card_id: StringName = _upgrades.get_card_id(card_index)
		var definition: UpgradeDefinition = _upgrades.catalog.get_definition(card_id)
		if definition == null:
			continue
		var view: UpgradeCardViewData = _builder.build_card(
			definition,
			_upgrades.get_card_unavailability_reason(card_id),
			_upgrades.is_specialization_offer()
		)
		var button := Button.new()
		button.name = "Card%d" % (card_index + 1)
		button.custom_minimum_size = Vector2(300.0, 330.0)
		button.text = _build_button_text(card_index, view)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.disabled = not view.is_selectable()
		button.pressed.connect(
			_on_card_pressed.bind(card_id, _displayed_offer_number)
		)
		_cards_container.add_child(button)
		_card_buttons.append(button)


func _build_button_text(card_index: int, view: UpgradeCardViewData) -> String:
	var parts := PackedStringArray([
		"%d  %s" % [card_index + 1, view.title],
		"%s • %s" % [view.branch_label, view.card_type_label],
		"",
		view.description,
		"",
		"Эффект: %s" % view.effect_summary,
		"Требования:\n%s" % view.requirements_summary,
	])
	if view.has_repeat_progress():
		parts.append("Получено: %s" % view.repeat_progress)
	if view.has_specialization_warning():
		parts.append("ВНИМАНИЕ: %s" % view.specialization_warning)
	if not view.is_selectable():
		parts.append("Недоступна: %s" % view.unavailable_reason_text)
	return "\n".join(parts)


func _on_card_pressed(card_id: StringName, offer_number: int) -> void:
	_submit_card(card_id, offer_number)


func _submit_card(card_id: StringName, offer_number: int) -> bool:
	if _selection_locked:
		return false
	if not _upgrades.is_offer_open():
		return false
	if offer_number != _upgrades.get_current_offer_number():
		return false
	_selection_locked = true
	_set_card_buttons_disabled(true)
	var accepted: bool = _upgrades.choose_card_by_id(card_id)
	if not accepted and offer_number == _upgrades.get_current_offer_number():
		_selection_locked = false
		_set_card_buttons_disabled(false)
	return accepted


func _set_card_buttons_disabled(disabled: bool) -> void:
	for button: Button in _card_buttons:
		if is_instance_valid(button):
			button.disabled = disabled


func _on_diagnostics_toggled(enabled: bool) -> void:
	_diagnostics_label.visible = enabled
	_refresh_diagnostics()


func _refresh_diagnostics() -> void:
	if not _diagnostics_toggle.button_pressed:
		_diagnostics_label.visible = false
		return
	_diagnostics_label.visible = true
	var lines := PackedStringArray()
	for definition: UpgradeDefinition in _upgrades.catalog.definitions:
		var reason_id: StringName = _upgrades.get_card_unavailability_reason(
			definition.card_id
		)
		var view: UpgradeCardViewData = _builder.build_card(
			definition,
			reason_id,
			false
		)
		lines.append("%s %s [%s] — %s" % [
			"✓" if view.is_selectable() else "×",
			view.title,
			view.card_id,
			view.unavailable_reason_text,
		])
	_diagnostics_label.text = "\n".join(lines)
