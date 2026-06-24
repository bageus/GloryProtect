extends SceneTree

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/combat_anchor_upgrade_catalog.tres"
)


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	assert(CATALOG.is_valid())
	assert(CATALOG.get_all_definitions().size() == 14)

	var overload_basic := CATALOG.get_definition(&"anchor_overload_basic")
	var overload_advanced := CATALOG.get_definition(&"anchor_overload_advanced")
	var electric_basic := CATALOG.get_definition(&"anchor_periodic_electric_basic")
	var electric_advanced := CATALOG.get_definition(&"anchor_periodic_electric_advanced")
	var install_basic := CATALOG.get_definition(&"anchor_install_speed_basic")
	var instant_remove := CATALOG.get_definition(&"anchor_instant_remove_all")
	assert(overload_basic != null and overload_basic.card_type == UpgradeDefinition.CardType.BASIC)
	assert(overload_advanced.prerequisite_card_ids == [&"anchor_overload_basic"])
	assert(electric_advanced.prerequisite_card_ids == [&"anchor_periodic_electric_basic"])
	assert(electric_basic.effect.target_id == CombatAnchorUpgradeRuntime.PERIODIC_ELECTRIC)
	assert(install_basic.effect.target_id == CombatAnchorUpgradeRuntime.INSTALL_SPEED_BONUS_RATIO)
	assert(instant_remove.card_type == UpgradeDefinition.CardType.INDIVIDUAL)

	var runtime := UpgradeRuntime.new()
	assert(runtime.record_card(overload_basic))
	assert(runtime.record_card(electric_basic))
	assert(runtime.is_branch_ready_for_specialization(&"anchors"))
	var generator := UpgradeSpecializationEventGenerator.new()
	generator.configure(CATALOG, runtime, 27)
	var offer: Array[UpgradeDefinition] = generator.generate_event_offer(&"anchors")
	assert(offer.size() == 3)
	var ids: Array[StringName] = []
	for definition: UpgradeDefinition in offer:
		assert(definition.branch_id == &"anchors")
		assert(definition.card_type == UpgradeDefinition.CardType.SPECIALIZATION)
		ids.append(definition.card_id)
	assert(ids.has(&"anchor_specialization_strong"))
	assert(ids.has(&"anchor_specialization_electric"))
	assert(ids.has(&"anchor_specialization_trap"))

	var strong_extra := CATALOG.get_definition(&"anchor_strong_second_install")
	var electric_extra := CATALOG.get_definition(&"anchor_electric_drop")
	var trap_extra := CATALOG.get_definition(&"anchor_trap_attach_explosion")
	assert(strong_extra.required_specialization_id == &"anchor_specialization_strong")
	assert(electric_extra.required_specialization_id == &"anchor_specialization_electric")
	assert(trap_extra.required_specialization_id == &"anchor_specialization_trap")

	print("Combat anchor catalog scenarios passed")
	quit()
