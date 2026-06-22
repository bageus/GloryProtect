extends SceneTree

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/shooter_upgrade_catalog.tres"
)
const DRAW_BALANCE: UpgradeDrawBalance = preload(
	"res://resources/upgrades/upgrade_draw_balance.tres"
)


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	_test_unlock_gates_base_lines()
	_test_unlock_does_not_advance_specialization()
	_test_piercing_requires_completed_line()
	_test_specialization_offer_and_extras()
	print("Shooter upgrade catalog scenarios passed")
	quit()


func _test_unlock_gates_base_lines() -> void:
	assert(CATALOG.is_valid())
	var runtime := UpgradeRuntime.new()
	var damage: UpgradeDefinition = CATALOG.get_definition(
		&"shooter_damage_basic"
	)
	assert(not CATALOG.is_available(damage, runtime))
	assert(runtime.record_card(CATALOG.get_definition(&"shooter_unlock")))
	assert(CATALOG.is_available(damage, runtime))


func _test_unlock_does_not_advance_specialization() -> void:
	var runtime := UpgradeRuntime.new()
	assert(runtime.record_card(CATALOG.get_definition(&"shooter_unlock")))
	assert(runtime.get_branch_progress(&"ranged") == 0)
	assert(runtime.record_card(CATALOG.get_definition(&"shooter_damage_basic")))
	assert(runtime.get_branch_progress(&"ranged") == 1)


func _test_piercing_requires_completed_line() -> void:
	var runtime := UpgradeRuntime.new()
	var generator := UpgradeDrawGenerator.new()
	generator.configure(DRAW_BALANCE, CATALOG, runtime, 24)
	var piercing: UpgradeDefinition = CATALOG.get_definition(
		&"shooter_piercing_bolt"
	)
	assert(
		generator.get_unavailability_reason(piercing)
		== &"branch_line_not_completed"
	)
	assert(runtime.record_card(CATALOG.get_definition(&"shooter_unlock")))
	assert(runtime.record_card(CATALOG.get_definition(&"shooter_range_basic")))
	assert(runtime.record_card(CATALOG.get_definition(&"shooter_range_advanced")))
	assert(generator.get_unavailability_reason(piercing) == &"")


func _test_specialization_offer_and_extras() -> void:
	var runtime := UpgradeRuntime.new()
	assert(runtime.record_card(CATALOG.get_definition(&"shooter_unlock")))
	assert(runtime.record_card(CATALOG.get_definition(&"shooter_damage_basic")))
	assert(runtime.record_card(CATALOG.get_definition(&"shooter_range_basic")))
	assert(runtime.is_branch_ready_for_specialization(&"ranged"))
	var events := UpgradeSpecializationEventGenerator.new()
	events.configure(CATALOG, runtime, 24)
	var offer: Array[UpgradeDefinition] = events.generate_event_offer(&"ranged")
	assert(offer.size() == 3)
	assert(runtime.record_card(CATALOG.get_definition(
		&"shooter_specialization_air_hunter"
	)))
	assert(CATALOG.is_available(
		CATALOG.get_definition(&"shooter_air_triple_shot"),
		runtime
	))
	assert(not CATALOG.is_available(
		CATALOG.get_definition(&"shooter_sniper_multi_pierce"),
		runtime
	))
