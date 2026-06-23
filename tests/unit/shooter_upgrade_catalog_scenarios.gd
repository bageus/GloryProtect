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
	_test_catalog_titles_match_rules()
	_test_ranged_branch_weight_and_unlock_behavior()
	_test_unlock_gates_base_lines()
	_test_unlock_does_not_advance_specialization()
	_test_piercing_requires_completed_line()
	_test_specialization_offer_and_extras()
	print("Shooter upgrade catalog scenarios passed")
	quit()


func _test_catalog_titles_match_rules() -> void:
	var expected_titles: Dictionary[StringName, String] = {
		&"shooter_unlock": "Стрелок",
		&"shooter_damage_basic": "Улучшенный выстрел арбалета",
		&"shooter_damage_advanced": "Мощный выстрел арбалета",
		&"shooter_range_basic": "Увеличенный радиус стрелка",
		&"shooter_range_advanced": "Мощный радиус стрелка",
		&"shooter_cooldown_basic": "Ускоренная атака стрелков",
		&"shooter_cooldown_advanced": "Мощное ускорение атаки стрелков",
		&"shooter_piercing_bolt": "Пробивающий болт",
		&"shooter_specialization_sniper": "Снайпер",
		&"shooter_specialization_air_hunter": "Охотник на летающих врагов",
		&"shooter_specialization_anchor_hunter": "Охотник на якорях",
	}
	for card_id: StringName in expected_titles:
		var definition: UpgradeDefinition = CATALOG.get_definition(card_id)
		assert(definition != null)
		assert(definition.title == expected_titles[card_id])


func _test_ranged_branch_weight_and_unlock_behavior() -> void:
	var runtime := UpgradeRuntime.new()
	var generator := UpgradeDrawGenerator.new()
	generator.configure(DRAW_BALANCE, CATALOG, runtime, 24)
	var starting_weight: int = generator.get_branch_weight(&"ranged")
	assert(starting_weight > 0)
	var unlock: UpgradeDefinition = CATALOG.get_definition(&"shooter_unlock")
	assert(unlock != null)
	generator.apply_selected_card(unlock)
	assert(generator.get_branch_weight(&"ranged") == starting_weight)


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
