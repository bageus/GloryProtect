extends SceneTree

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/technical_upgrade_catalog.tres"
)


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	_test_catalog_and_repeatability()
	_test_specialization_requirements()
	_test_runtime_reset()
	print("Upgrade runtime scenarios passed")
	quit()


func _test_catalog_and_repeatability() -> void:
	assert(CATALOG != null)
	assert(CATALOG.is_valid())
	var runtime := UpgradeRuntime.new()
	var unlock: UpgradeDefinition = CATALOG.get_definition(
		&"tech_unlock_turret"
	)
	var basic: UpgradeDefinition = CATALOG.get_definition(
		&"tech_turret_basic"
	)
	assert(unlock != null)
	assert(basic != null)
	assert(CATALOG.is_available(unlock, runtime))
	assert(not CATALOG.is_available(basic, runtime))
	assert(runtime.record_card(unlock))
	assert(CATALOG.is_available(basic, runtime))
	assert(runtime.record_card(basic))
	assert(runtime.record_card(basic))
	assert(runtime.get_repeat_count(basic.card_id) == 2)
	assert(not CATALOG.is_available(basic, runtime))


func _test_specialization_requirements() -> void:
	var runtime := UpgradeRuntime.new()
	var unlock: UpgradeDefinition = CATALOG.get_definition(
		&"tech_unlock_turret"
	)
	var basic: UpgradeDefinition = CATALOG.get_definition(
		&"tech_turret_basic"
	)
	var advanced: UpgradeDefinition = CATALOG.get_definition(
		&"tech_turret_advanced"
	)
	var specialization: UpgradeDefinition = CATALOG.get_definition(
		&"tech_turret_heavy"
	)
	var extra: UpgradeDefinition = CATALOG.get_definition(
		&"tech_turret_heavy_extra"
	)
	assert(not CATALOG.is_available(extra, runtime))
	assert(runtime.record_card(unlock))
	assert(runtime.record_card(basic))
	assert(runtime.record_card(advanced))
	assert(CATALOG.is_available(specialization, runtime))
	assert(runtime.record_card(specialization))
	assert(runtime.get_specialization(&"turret") == &"tech_turret_heavy")
	assert(runtime.is_specialization_closed(&"tech_turret_rapid"))
	assert(CATALOG.is_available(extra, runtime))


func _test_runtime_reset() -> void:
	var runtime := UpgradeRuntime.new()
	var general: UpgradeDefinition = CATALOG.get_definition(&"tech_general")
	assert(runtime.record_card(general))
	runtime.set_domain_flag(&"test_flag", true)
	runtime.add_domain_scalar(&"test_scalar", 2.0)
	runtime.reset_for_run()
	assert(runtime.get_selected_cards().is_empty())
	assert(runtime.get_repeat_count(general.card_id) == 0)
	assert(not runtime.get_domain_flag(&"test_flag"))
	assert(is_zero_approx(runtime.get_domain_scalar(&"test_scalar")))
