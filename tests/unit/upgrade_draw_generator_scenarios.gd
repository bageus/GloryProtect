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
	_test_weight_updates_and_reset()
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
	generator.reset_for_run()
	assert(generator.get_branch_weight(&"turret") == 10)
	assert(generator.get_branch_weight(&"steering") == 10)


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
