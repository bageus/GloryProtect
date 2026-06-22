extends SceneTree

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/medic_upgrade_catalog.tres"
)


func _init() -> void:
	_test_unlock_and_progress_rules()
	_test_line_and_individual_prerequisites()
	_test_specialization_exclusivity()
	print("Medic catalog scenarios passed")
	quit()


func _test_unlock_and_progress_rules() -> void:
	assert(CATALOG.is_valid())
	var runtime := UpgradeRuntime.new()
	var station: UpgradeDefinition = CATALOG.get_definition(&"medic_station")
	var amount: UpgradeDefinition = CATALOG.get_definition(&"medic_heal_amount_basic")
	var speed: UpgradeDefinition = CATALOG.get_definition(&"medic_heal_speed_basic")
	assert(station.card_type == UpgradeDefinition.CardType.UNLOCK)
	assert(not CATALOG.is_available(amount, runtime))
	assert(runtime.record_card(station))
	assert(runtime.get_branch_progress(&"healer") == 0)
	assert(CATALOG.is_available(amount, runtime))
	assert(CATALOG.is_available(speed, runtime))
	assert(runtime.record_card(amount))
	assert(runtime.get_branch_progress(&"healer") == 1)
	assert(not runtime.is_branch_ready_for_specialization(&"healer"))
	assert(runtime.record_card(speed))
	assert(runtime.get_branch_progress(&"healer") == 2)
	assert(runtime.is_branch_ready_for_specialization(&"healer"))


func _test_line_and_individual_prerequisites() -> void:
	var runtime := UpgradeRuntime.new()
	assert(runtime.record_card(CATALOG.get_definition(&"medic_station")))
	var basic: UpgradeDefinition = CATALOG.get_definition(&"medic_heal_amount_basic")
	var advanced: UpgradeDefinition = CATALOG.get_definition(&"medic_heal_amount_advanced")
	var health: UpgradeDefinition = CATALOG.get_definition(&"medic_role_health")
	var armor: UpgradeDefinition = CATALOG.get_definition(&"medic_role_armor")
	assert(not CATALOG.is_available(advanced, runtime))
	assert(not CATALOG.is_available(health, runtime))
	assert(not CATALOG.is_available(armor, runtime))
	assert(runtime.record_card(basic))
	assert(CATALOG.is_available(advanced, runtime))
	assert(runtime.record_card(advanced))
	assert(CATALOG.is_available(health, runtime))
	assert(CATALOG.is_available(armor, runtime))


func _test_specialization_exclusivity() -> void:
	var runtime := UpgradeRuntime.new()
	assert(runtime.record_card(CATALOG.get_definition(&"medic_station")))
	assert(runtime.record_card(CATALOG.get_definition(&"medic_heal_amount_basic")))
	assert(runtime.record_card(CATALOG.get_definition(&"medic_heal_speed_basic")))
	var field: UpgradeDefinition = CATALOG.get_definition(&"medic_specialization_field")
	var stimulant: UpgradeDefinition = CATALOG.get_definition(&"medic_specialization_stimulant")
	var field_combat: UpgradeDefinition = CATALOG.get_definition(&"medic_field_combat")
	var revival: UpgradeDefinition = CATALOG.get_definition(&"medic_stimulant_revival")
	assert(runtime.record_card(field))
	assert(runtime.get_specialization(&"healer") == field.card_id)
	assert(runtime.is_specialization_closed(stimulant.card_id))
	assert(CATALOG.is_available(field_combat, runtime))
	assert(not CATALOG.is_available(revival, runtime))
