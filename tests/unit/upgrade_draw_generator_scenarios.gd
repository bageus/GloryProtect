extends SceneTree

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/technical_upgrade_catalog.tres"
)
const DRAW_BALANCE: UpgradeDrawBalance = preload(
	"res://resources/upgrades/upgrade_draw_balance.tres"
)


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	_test_deterministic_unique_offer()
	_test_three_cards_from_same_branch()
	_test_fewer_than_three_remaining()
	_test_weight_updates_and_reset()
	_test_non_weighted_card_types()
	_test_diagnostics()
	print("Upgrade draw generator scenarios passed")
	quit()


func _test_deterministic_unique_offer() -> void:
	var first_runtime := UpgradeRuntime.new()
	var second_runtime := UpgradeRuntime.new()
	var first := UpgradeDrawGenerator.new()
	var second := UpgradeDrawGenerator.new()
	first.configure(DRAW_BALANCE, CATALOG, first_runtime, 12345)
	second.configure(DRAW_BALANCE, CATALOG, second_runtime, 12345)
	var first_offer: Array[UpgradeDefinition] = first.generate_offer()
	var second_offer: Array[UpgradeDefinition] = second.generate_offer()
	assert(first_offer.size() == second_offer.size())
	var seen: Dictionary[StringName, bool] = {}
	for index: int in range(first_offer.size()):
		assert(first_offer[index].card_id == second_offer[index].card_id)
		assert(not seen.has(first_offer[index].card_id))
		seen[first_offer[index].card_id] = true


func _test_three_cards_from_same_branch() -> void:
	var catalog := UpgradeCatalog.new()
	catalog.definitions = [
		_make_card(&"turret_a", &"turret", UpgradeDefinition.CardType.BASIC),
		_make_card(&"turret_b", &"turret", UpgradeDefinition.CardType.BASIC),
		_make_card(&"turret_c", &"turret", UpgradeDefinition.CardType.BASIC),
	]
	assert(catalog.is_valid())
	var generator := UpgradeDrawGenerator.new()
	generator.configure(DRAW_BALANCE, catalog, UpgradeRuntime.new(), 22)
	var offer: Array[UpgradeDefinition] = generator.generate_offer()
	assert(offer.size() == 3)
	var seen: Dictionary[StringName, bool] = {}
	for definition: UpgradeDefinition in offer:
		assert(definition.branch_id == &"turret")
		assert(not seen.has(definition.card_id))
		seen[definition.card_id] = true


func _test_fewer_than_three_remaining() -> void:
	var catalog := UpgradeCatalog.new()
	catalog.definitions = [
		_make_card(&"general_a", &"", UpgradeDefinition.CardType.GENERAL),
		_make_card(&"general_b", &"", UpgradeDefinition.CardType.GENERAL),
	]
	assert(catalog.is_valid())
	var generator := UpgradeDrawGenerator.new()
	generator.configure(DRAW_BALANCE, catalog, UpgradeRuntime.new(), 33)
	var offer: Array[UpgradeDefinition] = generator.generate_offer()
	assert(offer.size() == 2)
	assert(offer[0].card_id != offer[1].card_id)


func _test_weight_updates_and_reset() -> void:
	var runtime := UpgradeRuntime.new()
	var generator := UpgradeDrawGenerator.new()
	generator.configure(DRAW_BALANCE, CATALOG, runtime, 7)
	var basic: UpgradeDefinition = CATALOG.get_definition(&"tech_turret_basic")
	assert(generator.get_branch_weight(&"turret") == 10)
	assert(generator.get_branch_weight(&"anchors") == 10)
	assert(generator.get_branch_weight(&"healer") == 10)
	assert(generator.get_branch_weight(&"steering") == 10)
	generator.apply_selected_card(basic)
	assert(generator.get_branch_weight(&"turret") == 13)
	assert(generator.get_branch_weight(&"anchors") == 11)
	assert(generator.get_branch_weight(&"healer") == 11)
	assert(generator.get_branch_weight(&"steering") == 9)
	for _index: int in range(20):
		generator.apply_selected_card(
			_make_card(&"steering_pick", &"steering", UpgradeDefinition.CardType.BASIC)
		)
	assert(generator.get_branch_weight(&"turret") == 2)
	assert(generator.get_branch_weight(&"anchors") == 2)
	generator.reset_for_run()
	assert(generator.get_branch_weight(&"turret") == 10)
	assert(generator.get_branch_weight(&"steering") == 10)


func _test_non_weighted_card_types() -> void:
	var generator := UpgradeDrawGenerator.new()
	generator.configure(DRAW_BALANCE, CATALOG, UpgradeRuntime.new(), 9)
	var before: int = generator.get_branch_weight(&"turret")
	generator.apply_selected_card(CATALOG.get_definition(&"tech_unlock_turret"))
	assert(generator.get_branch_weight(&"turret") == before)
	generator.apply_selected_card(CATALOG.get_definition(&"tech_general"))
	assert(generator.get_branch_weight(&"turret") == before)


func _test_diagnostics() -> void:
	var runtime := UpgradeRuntime.new()
	var generator := UpgradeDrawGenerator.new()
	generator.configure(DRAW_BALANCE, CATALOG, runtime, 11)
	var advanced: UpgradeDefinition = CATALOG.get_definition(
		&"tech_turret_advanced"
	)
	assert(
		generator.get_unavailability_reason(advanced)
		== &"missing_prerequisite"
	)
	var individual: UpgradeDefinition = CATALOG.get_definition(&"tech_individual")
	assert(
		generator.get_unavailability_reason(individual)
		== &"branch_line_not_completed"
	)


func _make_card(
	card_id: StringName,
	branch_id: StringName,
	card_type: int
) -> UpgradeDefinition:
	var definition := UpgradeDefinition.new()
	definition.card_id = card_id
	definition.branch_id = branch_id
	definition.title = String(card_id)
	definition.card_type = card_type
	definition.repeat_limit = 1
	return definition
