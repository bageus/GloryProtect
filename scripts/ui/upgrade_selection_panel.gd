class_name UpgradeSelectionPanel
extends Control

@export_node_path("UpgradeSystem") var upgrade_system_path: NodePath

@onready var _upgrades: UpgradeSystem = get_node(upgrade_system_path)
@onready var _offer_label: Label = %OfferLabel
@onready var _cost_label: Label = %CostLabel
@onready var _cards_container: HBoxContainer = %CardsContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
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
	if key_event.keycode < KEY_1 or key_event.keycode > KEY_8:
		return
	var card_index: int = key_event.keycode - KEY_1
	if card_index >= _upgrades.get_card_count():
		return
	if _upgrades.choose_card(card_index):
		get_viewport().set_input_as_handled()


func _on_offer_opened(
	_offer_number: int,
	_cost: int,
	_card_count: int
) -> void:
	_show_current_offer()


func _on_offer_closed() -> void:
	visible = false


func _on_progress_reset() -> void:
	visible = false


func _show_current_offer() -> void:
	visible = true
	_offer_label.text = "ВЫБЕРИТЕ КАРТОЧКУ — ВЫДАЧА %d" % (
		_upgrades.get_current_offer_number()
	)
	_cost_label.text = "Стоимость: %d монет" % _upgrades.get_current_cost()
	_rebuild_card_buttons()


func _rebuild_card_buttons() -> void:
	for child: Node in _cards_container.get_children():
		_cards_container.remove_child(child)
		child.queue_free()

	for card_index: int in range(_upgrades.get_card_count()):
		var button := Button.new()
		button.custom_minimum_size = Vector2(260.0, 180.0)
		button.text = "%d\n%s\n\n%s" % [
			card_index + 1,
			_upgrades.get_card_title(card_index),
			_upgrades.get_card_description(card_index),
		]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_card_pressed.bind(card_index))
		_cards_container.add_child(button)


func _on_card_pressed(card_index: int) -> void:
	_upgrades.choose_card(card_index)
