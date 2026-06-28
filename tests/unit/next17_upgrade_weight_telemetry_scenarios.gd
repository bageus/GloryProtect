extends SceneTree

const DRAW_BALANCE: UpgradeDrawBalance = preload(
	"res://resources/upgrades/upgrade_draw_balance.tres"
)
const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/technical_upgrade_catalog.tres"
)
const GENERAL_POOL_ID: StringName = &"general"
const SELECTED_BRANCH_ID: StringName = &"turret"
const SIMULATION_OFFER_COUNT: int = 10000
const CARDS_PER_SIMULATION_POOL: int = 8


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_relationship_map_is_symmetric()
	_test_every_branch_selection_has_equal_total_delta()
	_test_general_pool_weight_floor()
	_test_long_run_pool_distribution()
	_test_economy_cost_targets()
	_test_telemetry_snapshot()
	print("NEXT-17 upgrade weight and telemetry scenarios passed")
	quit()


func _test_relationship_map_is_symmetric() -> void:
	assert(DRAW_BALANCE.is_valid())
	for raw_rule: Variant in DRAW_BALANCE.branch_rules:
		var rule: UpgradeBranchWeightRule = raw_rule as UpgradeBranchWeightRule
		assert(rule != null)
		assert(rule.related_branch_ids.size() == 2)
		assert(rule.opposing_branch_ids.size() == 2)
		for related_id: StringName in rule.related_branch_ids:
			var related_rule: UpgradeBranchWeightRule = DRAW_BALANCE.get_rule(related_id)
			assert(related_rule != null)
			assert(related_rule.related_branch_ids.has(rule.branch_id))
		for opposing_id: StringName in rule.opposing_branch_ids:
			var opposing_rule: UpgradeBranchWeightRule = DRAW_BALANCE.get_rule(opposing_id)
			assert(opposing_rule != null)
			assert(opposing_rule.opposing_branch_ids.has(rule.branch_id))


func _test_every_branch_selection_has_equal_total_delta() -> void:
	for raw_rule: Variant in DRAW_BALANCE.branch_rules:
		var rule: UpgradeBranchWeightRule = raw_rule as UpgradeBranchWeightRule
		assert(rule != null)
		var generator := UpgradeDrawGenerator.new()
		generator.configure(DRAW_BALANCE, CATALOG, UpgradeRuntime.new(), 101)
		var before: int = _total_branch_weight(generator)
		generator.apply_selected_card(_branch_card(rule.branch_id))
		var after: int = _total_branch_weight(generator)
		assert(after - before == 3)


func _test_general_pool_weight_floor() -> void:
	var branch_weight_samples: Array[int] = [0, 70, 100, 1000, 10000]
	for branch_weight: int in branch_weight_samples:
		var general_weight: int = DRAW_BALANCE.get_general_pool_weight(branch_weight)
		assert(general_weight >= DRAW_BALANCE.general_pool_weight)
		if branch_weight <= 0:
			continue
		var relative_share: float = (
			float(general_weight)
			/ float(general_weight + branch_weight)
		)
		assert(
			relative_share + 0.000001
			>= DRAW_BALANCE.minimum_general_pool_share
		)


func _test_long_run_pool_distribution() -> void:
	var catalog: UpgradeCatalog = _simulation_catalog()
	var generator := UpgradeDrawGenerator.new()
	generator.configure(DRAW_BALANCE, catalog, UpgradeRuntime.new(), 20260628)
	var slot_counts: Dictionary[StringName, int] = {}
	var selected_card: UpgradeDefinition = _branch_card(SELECTED_BRANCH_ID)
	var total_slots: int = 0
	for _offer_index: int in range(SIMULATION_OFFER_COUNT):
		var offer: Array[UpgradeDefinition] = generator.generate_offer()
		assert(offer.size() == DRAW_BALANCE.cards_per_offer)
		for definition: UpgradeDefinition in offer:
			var pool_id: StringName = (
				GENERAL_POOL_ID
				if definition.card_type == UpgradeDefinition.CardType.GENERAL
				else definition.branch_id
			)
			slot_counts[pool_id] = int(slot_counts.get(pool_id, 0)) + 1
			total_slots += 1
		generator.apply_selected_card(selected_card)
	assert(total_slots == SIMULATION_OFFER_COUNT * DRAW_BALANCE.cards_per_offer)
	var general_share: float = (
		float(slot_counts.get(GENERAL_POOL_ID, 0))
		/ float(total_slots)
	)
	assert(
		general_share
		>= DRAW_BALANCE.minimum_general_pool_share - 0.01
	)
	for raw_rule: Variant in DRAW_BALANCE.branch_rules:
		var rule: UpgradeBranchWeightRule = raw_rule as UpgradeBranchWeightRule
		assert(rule != null)
		if rule.branch_id == SELECTED_BRANCH_ID:
			continue
		var branch_share: float = (
			float(slot_counts.get(rule.branch_id, 0))
			/ float(total_slots)
		)
		assert(branch_share <= 0.40)


func _test_economy_cost_targets() -> void:
	var balance := UpgradeBalance.new()
	var first_twenty_total: int = 0
	for completed_count: int in range(20):
		first_twenty_total += balance.get_cost_for_completed_count(completed_count)
	assert(first_twenty_total == 1050)
	assert(balance.get_cost_for_completed_count(0) == 5)
	assert(balance.get_cost_for_completed_count(19) == 100)
	assert(balance.get_cost_for_completed_count(20) == 200)
	assert(balance.get_cost_for_completed_count(21) == 400)
	assert(balance.get_cost_for_completed_count(22) == 800)
	var target_minutes: float = 20.0
	var required_coins_per_minute: float = (
		float(first_twenty_total) / target_minutes
	)
	assert(is_equal_approx(required_coins_per_minute, 52.5))
	var fastest_target_rate: float = float(first_twenty_total) / 18.0
	var slowest_target_rate: float = float(first_twenty_total) / 22.0
	assert(fastest_target_rate > required_coins_per_minute)
	assert(slowest_target_rate < required_coins_per_minute)


func _test_telemetry_snapshot() -> void:
	var timeline: Array = [{
		"time_seconds": 120.0,
		"purchase_number": 3,
		"card_id": &"example",
		"branch_id": &"turret",
		"cost": 15,
		"coins_after": 2,
		"specialization": false,
	}]
	var slots: Dictionary = {&"general": 4, &"turret": 6}
	var specializations: Array[int] = [5, 12]
	var snapshot := RunStatisticsSnapshot.new(
		600.0,
		200,
		10,
		12,
		&"test",
		300,
		290,
		timeline,
		slots,
		specializations
	)
	assert(snapshot.earned_coins == 300)
	assert(snapshot.spent_coins == 290)
	assert(is_equal_approx(snapshot.coins_per_minute, 30.0))
	assert(snapshot.purchase_timeline.size() == 1)
	assert(snapshot.offer_slot_counts[&"general"] == 4)
	assert(snapshot.specialization_purchase_numbers == [5, 12])


func _simulation_catalog() -> UpgradeCatalog:
	var catalog := UpgradeCatalog.new()
	var definitions: Array[UpgradeDefinition] = []
	for card_index: int in range(CARDS_PER_SIMULATION_POOL):
		var general := UpgradeDefinition.new()
		general.card_id = StringName("simulation_general_%d" % card_index)
		general.title = "Simulation General %d" % card_index
		general.card_type = UpgradeDefinition.CardType.GENERAL
		general.repeat_limit = 99
		definitions.append(general)
	for raw_rule: Variant in DRAW_BALANCE.branch_rules:
		var rule: UpgradeBranchWeightRule = raw_rule as UpgradeBranchWeightRule
		assert(rule != null)
		for card_index: int in range(CARDS_PER_SIMULATION_POOL):
			var branch_card := UpgradeDefinition.new()
			branch_card.card_id = StringName(
				"simulation_%s_%d" % [String(rule.branch_id), card_index]
			)
			branch_card.branch_id = rule.branch_id
			branch_card.title = "Simulation %s %d" % [
				String(rule.branch_id),
				card_index,
			]
			branch_card.card_type = UpgradeDefinition.CardType.BASIC
			branch_card.repeat_limit = 99
			definitions.append(branch_card)
	catalog.definitions = definitions
	assert(catalog.is_valid())
	return catalog


func _total_branch_weight(generator: UpgradeDrawGenerator) -> int:
	var result: int = 0
	for raw_rule: Variant in DRAW_BALANCE.branch_rules:
		var rule: UpgradeBranchWeightRule = raw_rule as UpgradeBranchWeightRule
		assert(rule != null)
		result += generator.get_branch_weight(rule.branch_id)
	return result


func _branch_card(branch_id: StringName) -> UpgradeDefinition:
	var definition := UpgradeDefinition.new()
	definition.card_id = StringName("test_%s" % String(branch_id))
	definition.branch_id = branch_id
	definition.title = String(branch_id)
	definition.card_type = UpgradeDefinition.CardType.BASIC
	definition.repeat_limit = 1
	return definition
