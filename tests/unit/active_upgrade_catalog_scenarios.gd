extends SceneTree

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/active_game_upgrade_catalog.tres"
)
const TURRET: UpgradeCatalog = preload(
	"res://resources/upgrades/turret_branch_upgrade_catalog.tres"
)
const MELEE: UpgradeCatalog = preload(
	"res://resources/upgrades/melee_defender_upgrade_catalog.tres"
)
const MEDIC: UpgradeCatalog = preload(
	"res://resources/upgrades/medic_upgrade_catalog.tres"
)
const SHOOTER: UpgradeCatalog = preload(
	"res://resources/upgrades/shooter_upgrade_catalog.tres"
)


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	assert(CATALOG.is_valid())
	var expected_count: int = (
		TURRET.get_all_definitions().size()
		+ MELEE.get_all_definitions().size()
		+ MEDIC.get_all_definitions().size()
		+ SHOOTER.get_all_definitions().size()
	)
	assert(CATALOG.get_all_definitions().size() == expected_count)
	assert(CATALOG.get_definition(&"common_add_defender") != null)
	assert(CATALOG.get_definition(&"turret_post") != null)
	assert(CATALOG.get_definition(&"turret_heavy_explosive_fifth") != null)
	assert(CATALOG.get_definition(&"turret_electric_orb_fifth") != null)
	assert(CATALOG.get_definition(&"melee_damage_basic") != null)
	assert(CATALOG.get_definition(&"melee_specialization_heavy") != null)
	assert(CATALOG.get_definition(&"medic_station") != null)
	assert(CATALOG.get_definition(&"medic_specialization_field") != null)
	assert(CATALOG.get_definition(&"shooter_unlock") != null)
	assert(CATALOG.get_definition(&"shooter_specialization_sniper") != null)
	_test_upgrade_system_catalog_api(expected_count)
	_test_melee_specialization_offer()
	_test_shooter_specialization_offer()
	print("Active upgrade catalog scenarios passed")
	quit()


func _test_upgrade_system_catalog_api(expected_count: int) -> void:
	var system := UpgradeSystem.new()
	system.catalog = CATALOG
	assert(system.get_all_card_definitions().size() == expected_count)
	system.free()


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
