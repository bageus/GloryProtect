class_name UpgradeSystem
extends Node

signal offer_opened(offer_number: int, cost: int, card_count: int)
signal specialization_offer_opened(branch_id: StringName, offer_number: int, cost: int, card_count: int)
signal offer_closed
signal card_selected(card_index: int, offer_number: int, cost: int)
signal card_selected_by_id(card_id: StringName, offer_number: int, cost: int)
signal progress_reset

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("RunEconomy") var run_economy_path: NodePath
@export_node_path("BuildableInventory") var buildable_inventory_path: NodePath = NodePath("../BuildableInventory")
@export_node_path("CrewManager") var crew_manager_path: NodePath = NodePath("../World/Platform/CrewManager")
@export_node_path("CrewReplacementController") var replacement_controller_path: NodePath = NodePath("../CrewReplacementController")
@export var balance: UpgradeBalance
@export var catalog: UpgradeCatalog = preload("res://resources/upgrades/technical_upgrade_catalog.tres")
@export var draw_balance: UpgradeDrawBalance = preload("res://resources/upgrades/upgrade_draw_balance.tres")
@export var deterministic_seed: int = 0

var _completed_purchases: int = 0
var _offer_open: bool = false
var _selection_in_progress: bool = false
var _specialization_offer: bool = false
var _specialization_branch: StringName = &""
var _current_offer: Array[UpgradeDefinition] = []
var _runtime := UpgradeRuntime.new()
var _effect_applier := UpgradeEffectApplier.new()
var _draw_generator := UpgradeDrawGenerator.new()
var _specialization_generator := UpgradeSpecializationEventGenerator.new()

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _economy: RunEconomy = get_node(run_economy_path)
@onready var _buildables: BuildableInventory = get_node(buildable_inventory_path)
@onready var _crew: CrewManager = get_node(crew_manager_path)
@onready var _replacements: CrewReplacementController = get_node(replacement_controller_path)


func _ready() -> void:
	assert(balance != null, "UpgradeSystem requires UpgradeBalance")
	assert(catalog != null and catalog.is_valid(), "UpgradeSystem catalog is invalid")
	assert(draw_balance != null and draw_balance.is_valid(), "Upgrade draw balance is invalid")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_effect_applier.configure(_buildables, _runtime, _crew, _replacements)
	_draw_generator.configure(draw_balance, catalog, _runtime, deterministic_seed)
	_specialization_generator.configure(catalog, _runtime, _get_specialization_seed())
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
	return _current_offer.size() if _offer_open else draw_balance.cards_per_offer


func get_card_definition(card_index: int) -> UpgradeDefinition:
	return _get_offer_definition(card_index)


func get_all_card_definitions() -> Array[UpgradeDefinition]:
	return catalog.definitions.duplicate()


func get_card_id(card_index: int) -> StringName:
	var definition: UpgradeDefinition = _get_offer_definition(card_index)
	return definition.card_id if definition != null else &""


func get_card_title(card_index: int) -> String:
	var definition: UpgradeDefinition = _get_offer_definition(card_index)
	return definition.title if definition != null else ""


func get_card_description(card_index: int) -> String:
	var definition: UpgradeDefinition = _get_offer_definition(card_index)
	return definition.description if definition != null else ""


func get_card_unavailability_reason(card_id: StringName) -> StringName:
	var definition: UpgradeDefinition = catalog.get_definition(card_id)
	if _specialization_offer:
		return _get_specialization_unavailability_reason(definition)
	return _draw_generator.get_unavailability_reason(definition)


func get_branch_weight(branch_id: StringName) -> int:
	return _draw_generator.get_branch_weight(branch_id)


func set_draw_seed(seed: int) -> void:
	_draw_generator.set_seed(seed)
	_specialization_generator.set_seed(seed + 1)


func is_offer_open() -> bool:
	return _offer_open


func is_selection_in_progress() -> bool:
	return _selection_in_progress


func is_specialization_offer() -> bool:
	return _offer_open and _specialization_offer


func get_specialization_offer_branch() -> StringName:
	return _specialization_branch if is_specialization_offer() else &""


func choose_card(card_index: int) -> bool:
	var definition: UpgradeDefinition = _get_offer_definition(card_index)
	if definition == null:
		return false
	return choose_card_for_offer(
		definition.card_id,
		get_current_offer_number()
	)


func choose_card_by_id(card_id: StringName) -> bool:
	return choose_card_for_offer(card_id, get_current_offer_number())


func choose_card_for_offer(
	card_id: StringName,
	expected_offer_number: int
) -> bool:
	if _selection_in_progress:
		return false
	if expected_offer_number != get_current_offer_number():
		return false
	if not _offer_open or _game_flow.state != GameFlowController.RunState.CARD_SELECTION:
		return false
	var offer_index: int = _find_offer_index(card_id)
	if offer_index < 0:
		return false
	var definition: UpgradeDefinition = _current_offer[offer_index]
	if get_card_unavailability_reason(definition.card_id) != &"":
		return false
	if not _effect_applier.can_apply(definition):
		return false
	_selection_in_progress = true
	var offer_number: int = get_current_offer_number()
	var cost: int = get_current_cost()
	if not _economy.spend_coins(cost, &"upgrade_card"):
		_selection_in_progress = false
		return false
	if not _effect_applier.apply_effect(definition):
		_economy.add_coins(cost, &"upgrade_refund")
		_selection_in_progress = false
		return false
	if not _runtime.record_card(definition):
		_economy.add_coins(cost, &"upgrade_refund")
		_selection_in_progress = false
		return false
	_draw_generator.apply_selected_card(definition)
	_completed_purchases += 1
	card_selected.emit(offer_index, offer_number, cost)
	card_selected_by_id.emit(definition.card_id, offer_number, cost)
	_selection_in_progress = false
	if _economy.can_afford(get_current_cost()):
		_generate_offer()
		_emit_current_offer()
	else:
		_close_offer()
	return true


func reset_for_run() -> void:
	_cancel_offer()
	_completed_purchases = 0
	_selection_in_progress = false
	_current_offer.clear()
	_specialization_offer = false
	_specialization_branch = &""
	_runtime.reset_for_run()
	_draw_generator.reset_for_run()
	_crew.reset_run_modifiers()
	_replacements.reset_run_modifiers()
	progress_reset.emit()


func _open_offer_if_affordable() -> void:
	if _offer_open or _game_flow.state != GameFlowController.RunState.RUNNING:
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
	_specialization_offer = false
	_specialization_branch = &""
	if _generate_specialization_offer():
		return
	_current_offer = _draw_generator.generate_offer()
	for index: int in range(_current_offer.size() - 1, -1, -1):
		if not _effect_applier.can_apply(_current_offer[index]):
			_current_offer.remove_at(index)


func _generate_specialization_offer() -> bool:
	var branch_id: StringName = _specialization_generator.choose_ready_branch()
	if branch_id == &"":
		return false
	var offer: Array[UpgradeDefinition] = _specialization_generator.generate_event_offer(branch_id)
	if offer.size() != 3:
		return false
	for definition: UpgradeDefinition in offer:
		if not _effect_applier.can_apply(definition):
			return false
	_specialization_offer = true
	_specialization_branch = branch_id
	_current_offer = offer
	return true


func _emit_current_offer() -> void:
	offer_opened.emit(get_current_offer_number(), get_current_cost(), _current_offer.size())
	if _specialization_offer:
		specialization_offer_opened.emit(_specialization_branch, get_current_offer_number(), get_current_cost(), _current_offer.size())


func _close_offer() -> void:
	if not _offer_open:
		return
	_cancel_offer()
	_game_flow.finish_card_selection()


func _cancel_offer() -> void:
	_selection_in_progress = false
	if not _offer_open:
		_current_offer.clear()
		_specialization_offer = false
		_specialization_branch = &""
		return
	_offer_open = false
	_current_offer.clear()
	_specialization_offer = false
	_specialization_branch = &""
	offer_closed.emit()


func _get_offer_definition(card_index: int) -> UpgradeDefinition:
	if card_index < 0 or card_index >= _current_offer.size():
		return null
	return _current_offer[card_index]


func _find_offer_index(card_id: StringName) -> int:
	for index: int in range(_current_offer.size()):
		if _current_offer[index].card_id == card_id:
			return index
	return -1


func _get_specialization_unavailability_reason(definition: UpgradeDefinition) -> StringName:
	if definition == null or not definition.is_valid():
		return &"invalid_definition"
	if definition.card_type != UpgradeDefinition.CardType.SPECIALIZATION:
		return &"not_specialization_card"
	if definition.branch_id != _specialization_branch:
		return &"wrong_specialization_branch"
	if _runtime.has_specialization(definition.branch_id):
		return &"specialization_already_selected"
	if _runtime.is_specialization_closed(definition.card_id):
		return &"specialization_closed"
	if _runtime.get_repeat_count(definition.card_id) >= definition.repeat_limit:
		return &"repeat_limit_reached"
	return &""


func _get_specialization_seed() -> int:
	return 0 if deterministic_seed == 0 else deterministic_seed + 1


func _on_coins_changed(_previous_amount: int, _current_amount: int, _delta: int, _source: StringName) -> void:
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
