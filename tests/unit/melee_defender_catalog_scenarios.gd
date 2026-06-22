extends SceneTree

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/melee_defender_upgrade_catalog.tres"
)
const DRAW_BALANCE: UpgradeDrawBalance = preload(
	"res://resources/upgrades/upgrade_draw_balance.tres"
)


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	_test_base_and_advanced_lines()
	_test_individual_cards_need_completed_line()
	_test_specialization_closes_alternatives()
	_test_specialization_extras_follow_selected_path()
	print("Melee defender catalog scenarios passed")
	quit()


func _test_base_and_advanced_lines() -> void:
	assert(CATALOG.is_valid())
	var runtime := UpgradeRuntime.new()
	var advanced_ids: Array[StringName] = [
		&"melee_damage_advanced",
		&"melee_cooldown_advanced",
		&"melee_health_advanced",
	]
	var basic_ids: Array[StringName] = [
		&"melee_damage_basic",
		&"melee_cooldown_basic",
		&"melee_health_basic",
	]
	for index: int in range(advanced_ids.size()):
		var advanced: UpgradeDefinition = CATALOG.get_definition(
			advanced_ids[index]
		)
		assert(not CATALOG.is_available(advanced, runtime))
		assert(runtime.record_card(CATALOG.get_definition(basic_ids[index])))
		assert(CATALOG.is_available(advanced, runtime))


func _test_individual_cards_need_completed_line() -> void:
	var runtime := UpgradeRuntime.new()
	var generator := UpgradeDrawGenerator.new()
	generator.configure(DRAW_BALANCE, CATALOG, runtime, 101)
	var survivability: UpgradeDefinition = CATALOG.get_definition(
		&"melee_individual_max_survivability"
	)
	var armor: UpgradeDefinition = CATALOG.get_definition(
		&"melee_individual_armor"
	)
	assert(
		generator.get_unavailability_reason(survivability)
		== &"branch_line_not_completed"
	)
	assert(
		generator.get_unavailability_reason(armor)
		== &"branch_line_not_completed"
	)
	assert(runtime.record_card(CATALOG.get_definition(&"melee_damage_basic")))
	assert(runtime.record_card(CATALOG.get_definition(&"melee_damage_advanced")))
	assert(generator.get_unavailability_reason(survivability) == &"")
	assert(generator.get_unavailability_reason(armor) == &"")


func _test_specialization_closes_alternatives() -> void:
	var runtime := UpgradeRuntime.new()
	var heavy: UpgradeDefinition = CATALOG.get_definition(
		&"melee_specialization_heavy"
	)
	assert(runtime.record_card(heavy))
	assert(runtime.get_specialization(&"melee") == heavy.card_id)
	assert(runtime.is_specialization_closed(&"melee_specialization_duelist"))
	assert(runtime.is_specialization_closed(&"melee_specialization_assault"))


func _test_specialization_extras_follow_selected_path() -> void:
	var runtime := UpgradeRuntime.new()
	var heavy_extra: UpgradeDefinition = CATALOG.get_definition(
		&"melee_heavy_shield"
	)
	var duelist_extra: UpgradeDefinition = CATALOG.get_definition(
		&"melee_duelist_double_attack"
	)
	assert(not CATALOG.is_available(heavy_extra, runtime))
	assert(not CATALOG.is_available(duelist_extra, runtime))
	assert(runtime.record_card(CATALOG.get_definition(
		&"melee_specialization_heavy"
	)))
	assert(CATALOG.is_available(heavy_extra, runtime))
	assert(not CATALOG.is_available(duelist_extra, runtime))
