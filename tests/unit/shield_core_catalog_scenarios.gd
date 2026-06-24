extends SceneTree

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/shield_core_upgrade_catalog.tres"
)


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	assert(CATALOG.is_valid())
	assert(CATALOG.get_all_definitions().size() == 9)

	var capacity_basic := CATALOG.get_definition(&"shield_capacity_basic")
	var capacity_advanced := CATALOG.get_definition(&"shield_capacity_advanced")
	var recharge_basic := CATALOG.get_definition(&"shield_recharge_basic")
	var recharge_advanced := CATALOG.get_definition(&"shield_recharge_advanced")
	var contact_basic := CATALOG.get_definition(&"shield_contact_basic")
	var contact_advanced := CATALOG.get_definition(&"shield_contact_advanced")
	assert(capacity_basic.card_type == UpgradeDefinition.CardType.BASIC)
	assert(capacity_advanced.prerequisite_card_ids == [&"shield_capacity_basic"])
	assert(recharge_advanced.prerequisite_card_ids == [&"shield_recharge_basic"])
	assert(contact_advanced.prerequisite_card_ids == [&"shield_contact_basic"])
	assert(capacity_basic.effect.target_id == ShieldCoreUpgradeRuntime.CAPACITY_BONUS_RATIO)
	assert(recharge_basic.effect.target_id == ShieldCoreUpgradeRuntime.RECHARGE_BONUS_RATIO)
	assert(contact_basic.effect.target_id == ShieldCoreUpgradeRuntime.CONTACT_WIDTH_BONUS_RATIO)

	var runtime := UpgradeRuntime.new()
	assert(runtime.record_card(capacity_basic))
	assert(runtime.record_card(recharge_basic))
	assert(runtime.is_branch_ready_for_specialization(&"shield_core"))
	var generator := UpgradeSpecializationEventGenerator.new()
	generator.configure(CATALOG, runtime, 28)
	var offer: Array[UpgradeDefinition] = generator.generate_event_offer(&"shield_core")
	assert(offer.size() == 3)
	var ids: Array[StringName] = []
	for definition: UpgradeDefinition in offer:
		assert(definition.card_type == UpgradeDefinition.CardType.SPECIALIZATION)
		ids.append(definition.card_id)
	assert(ids.has(ShieldCoreUpgradeRuntime.FOCUSED))
	assert(ids.has(ShieldCoreUpgradeRuntime.DISTRIBUTED))
	assert(ids.has(ShieldCoreUpgradeRuntime.SURGE))

	print("Shield core catalog scenarios passed")
	quit()
