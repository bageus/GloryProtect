class_name UpgradeSystem
extends Node

signal offer_opened(offer_number: int, cost: int, card_count: int)
signal offer_closed
signal card_selected(card_index: int, offer_number: int, cost: int)
signal card_selected_by_id(card_id: StringName, offer_number: int, cost: int)
signal progress_reset

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("RunEconomy") var run_economy_path: NodePath
@export_node_path("BuildableInventory") var buildable_inventory_path: NodePath = NodePath("../BuildableInventory")
@export var balance: UpgradeBalance
@export var catalog: UpgradeCatalog = preload(
	"res://resources/upgrades/technical_upgrade_catalog.tres"
)

var _completed_purchases: int = 0
var _offer_open: bool = false
var _current_offer: Array[UpgradeDefinition] = []
var _runtime := UpgradeRuntime.new()
var _effect_applier := UpgradeEffectApplier.new()
var _rng := RandomNumberGenerator.new()

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _economy: RunEconomy = get_node(run_economy_path)
@onready var _buildables: BuildableInventory = get_node(buildable_inventory_path)


func _ready() -> void:
	assert(balance != null, "UpgradeSystem requires UpgradeBalance")
	assert(catalog != null and catalog.is_valid(), "UpgradeSystem catalog is invalid")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_effect_applier.configure(_buildables, _runtime)
	_economy.coins_changed.connect(_on_coins_changed)
	_game_flow.run_state_changed.connect(_on_run_state_changed)


func get_runtime() -> UpgradeRuntime:
	return _runtime


func get_completed_purchase_count() -> int:
	return _completed_purchases


func get_current_offer_number() -> int:
	return _completed_purchases + 1


func get_current_cost() -> int:
	return balance.get_cost_for_completed_count(_completed_purchases)


func get_card_count() -> int:
	return _current_offer.size() if _offer_open else balance.cards_per_offer


func get_card_id(card_index: int) -> StringName:
	var definition: UpgradeDefinition = _get_offer_definition(card_index)
	return definition.card_id if definition != null else &""


func get_card_title(card_index: int) -> String:
	var definition: UpgradeDefinition = _get_offer_definition(card_index)
	return definition.title if definition != null else ""


func get_card_description(card_index: int) -> String:
	var definition: UpgradeDefinition = _get_offer_definition(card_index)
	return definition.description if definition != null else ""


func is_offer_open() -> bool:
	return _offer_open


func choose_card(card_index: int) -> bool:
	if not _offer_open:
		return false
	if _game_flow.state != GameFlowController.RunState.CARD_SELECTION:
		return false
	var definition: UpgradeDefinition = _get_offer_definition(card_index)
	if definition == null:
		return false
	if not catalog.is_available(definition, _runtime):
		return false
	if not _effect_applier.can_apply(definition):
		return false

	var offer_number: int = get_current_offer_number()
	var cost: int = get_current_cost()
	if not _economy.spend_coins(cost, &"upgrade_card"):
		return false
	if not _effect_applier.apply_effect(definition):
		_economy.add_coins(cost, &"upgrade_refund")
		return false
	if not _runtime.record_card(definition):
		_economy.add_coins(cost, &"upgrade_refund")
		return false

	_completed_purchases += 1
	card_selected.emit(card_index, offer_number, cost)
	card_selected_by_id.emit(definition.card_id, offer_number, cost)

	if _economy.can_afford(get_current_cost()):
		_generate_offer()
		_emit_current_offer()
	else:
		_close_offer()
	return true


func reset_for_run() -> void:
	_cancel_offer()
	_completed_purchases = 0
	_current_offer.clear()
	_runtime.reset_for_run()
	progress_reset.emit()


func _open_offer_if_affordable() -> void:
	if _offer_open:
		return
	if _game_flow.state != GameFlowController.RunState.RUNNING:
		return
	if not _economy.can_afford(get_current_cost()):
		return
	_generate_offer()
	if _current_offer.is_empty():
		return
	_offer_open = true
	_game_flow.begin_card_selection()
	_emit_current_offer()


func _generate_offer() -> void:
	_current_offer.clear()
	var candidates: Array[UpgradeDefinition] = catalog.get_available_definitions(_runtime)
	while not candidates.is_empty() and _current_offer.size() < balance.cards_per_offer:
		var index: int = _rng.randi_range(0, candidates.size() - 1)
		var definition: UpgradeDefinition = candidates[index]
		candidates.remove_at(index)
		if _effect_applier.can_apply(definition):
			_current_offer.append(definition)


func _emit_current_offer() -> void:
	offer_opened.emit(
		get_current_offer_number(),
		get_current_cost(),
		_current_offer.size()
	)


func _close_offer() -> void:
	if not _offer_open:
		return
	_cancel_offer()
	_game_flow.finish_card_selection()


func _cancel_offer() -> void:
	if not _offer_open:
		_current_offer.clear()
		return
	_offer_open = false
	_current_offer.clear()
	offer_closed.emit()


func _get_offer_definition(card_index: int) -> UpgradeDefinition:
	if card_index < 0 or card_index >= _current_offer.size():
		return null
	return _current_offer[card_index]


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
		_cancel_offer()
