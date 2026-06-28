extends SceneTree

const DRAW_BALANCE: UpgradeDrawBalance = preload(
	"res://resources/upgrades/upgrade_draw_balance.tres"
)
const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/technical_upgrade_catalog.tres"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_relationship_map_is_symmetric()
	_test_every_branch_selection_has_equal_total_delta()
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
