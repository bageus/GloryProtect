class_name UpgradeSystem
extends Node

signal offer_opened(offer_number: int, cost: int, card_count: int)
signal offer_closed
signal card_selected(card_index: int, offer_number: int, cost: int)
signal progress_reset

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("RunEconomy") var run_economy_path: NodePath
@export var balance: UpgradeBalance

var _completed_purchases: int = 0
var _offer_open: bool = false

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _economy: RunEconomy = get_node(run_economy_path)


func _ready() -> void:
	assert(balance != null, "UpgradeSystem requires UpgradeBalance")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_economy.coins_changed.connect(_on_coins_changed)
	_game_flow.run_state_changed.connect(_on_run_state_changed)


func get_completed_purchase_count() -> int:
	return _completed_purchases


func get_current_offer_number() -> int:
	return _completed_purchases + 1


func get_current_cost() -> int:
	return balance.get_cost_for_completed_count(_completed_purchases)


func get_card_count() -> int:
	return balance.cards_per_offer


func get_card_title(card_index: int) -> String:
	if card_index < 0 or card_index >= get_card_count():
		return ""
	return balance.placeholder_title


func get_card_description(card_index: int) -> String:
	if card_index < 0 or card_index >= get_card_count():
		return ""
	return balance.placeholder_description


func is_offer_open() -> bool:
	return _offer_open


func choose_card(card_index: int) -> bool:
	if not _offer_open:
		return false
	if _game_flow.state != GameFlowController.RunState.CARD_SELECTION:
		return false
	if card_index < 0 or card_index >= get_card_count():
		return false

	var offer_number: int = get_current_offer_number()
	var cost: int = get_current_cost()
	if not _economy.spend_coins(cost, &"upgrade_card"):
		return false

	_completed_purchases += 1
	card_selected.emit(card_index, offer_number, cost)

	if _economy.can_afford(get_current_cost()):
		_emit_current_offer()
	else:
		_close_offer()
	return true


func reset_for_run() -> void:
	_completed_purchases = 0
	_offer_open = false
	progress_reset.emit()


func _open_offer_if_affordable() -> void:
	if _offer_open:
		return
	if _game_flow.state != GameFlowController.RunState.RUNNING:
		return
	if not _economy.can_afford(get_current_cost()):
		return

	_offer_open = true
	_game_flow.begin_card_selection()
	_emit_current_offer()


func _emit_current_offer() -> void:
	offer_opened.emit(
		get_current_offer_number(),
		get_current_cost(),
		get_card_count()
	)


func _close_offer() -> void:
	if not _offer_open:
		return
	_offer_open = false
	offer_closed.emit()
	_game_flow.finish_card_selection()


func _on_coins_changed(
	_previous_amount: int,
	_current_amount: int,
	_delta: int,
	_source: StringName
) -> void:
	_open_offer_if_affordable()


func _on_run_state_changed(previous_state: int, new_state: int) -> void:
	if new_state == GameFlowController.RunState.START_DELAY:
		if previous_state != GameFlowController.RunState.MANUAL_PAUSE:
			reset_for_run()
		return

	if new_state == GameFlowController.RunState.RUNNING:
		call_deferred("_open_offer_if_affordable")
		return

	if new_state == GameFlowController.RunState.GAME_OVER:
		_offer_open = false
