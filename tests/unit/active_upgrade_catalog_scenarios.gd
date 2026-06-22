extends SceneTree

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/active_game_upgrade_catalog.tres"
)


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	assert(CATALOG.is_valid())
	assert(CATALOG.get_definition(&"common_add_defender") != null)
	assert(CATALOG.get_definition(&"common_turret_post") != null)
	assert(CATALOG.get_definition(&"melee_damage_basic") != null)
	assert(CATALOG.get_definition(&"melee_specialization_heavy") != null)
	assert(CATALOG.get_definition(&"shooter_unlock") != null)
	assert(CATALOG.get_definition(&"shooter_specialization_sniper") != null)
	assert(CATALOG.get_all_definitions().size() > CATALOG.definitions.size())
	_test_melee_specialization_offer()
	_test_shooter_specialization_offer()
	print("Active upgrade catalog scenarios passed")
	quit()


func _test_melee_specialization_offer() -> void:
	var runtime := UpgradeRuntime.new()
	assert(runtime.record_card(CATALOG.get_definition(&"melee_damage_basic")))
	assert(runtime.record_card(CATALOG.get_definition(&"melee_cooldown_basic")))
	assert(runtime.is_branch_ready_for_specialization(&"melee"))
	var generator := UpgradeSpecializationEventGenerator.new()
	generator.configure(CATALOG, runtime, 23)
	var offer: Array[UpgradeDefinition] = generator.generate_event_offer(&"melee")
	assert(offer.size() == 3)
	for definition: UpgradeDefinition in offer:
		assert(definition.branch_id == &"melee")
		assert(definition.card_type == UpgradeDefinition.CardType.SPECIALIZATION)


func _test_shooter_specialization_offer() -> void:
	var runtime := UpgradeRuntime.new()
	assert(runtime.record_card(CATALOG.get_definition(&"shooter_unlock")))
	assert(runtime.record_card(CATALOG.get_definition(&"shooter_damage_basic")))
	assert(runtime.record_card(CATALOG.get_definition(&"shooter_range_basic")))
	assert(runtime.is_branch_ready_for_specialization(&"ranged"))
	var generator := UpgradeSpecializationEventGenerator.new()
	generator.configure(CATALOG, runtime, 24)
	var offer: Array[UpgradeDefinition] = generator.generate_event_offer(&"ranged")
	assert(offer.size() == 3)
	for definition: UpgradeDefinition in offer:
		assert(definition.branch_id == &"ranged")
		assert(definition.card_type == UpgradeDefinition.CardType.SPECIALIZATION)
