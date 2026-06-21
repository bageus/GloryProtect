extends SceneTree

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/common_repeatable_upgrade_catalog.tres"
)


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	_test_base_lines()
	_test_specializations()
	_test_catalog_prerequisites()
	_test_independent_volley_counters()
	print("Turret upgrade runtime scenarios passed")
	quit()


func _test_base_lines() -> void:
	var upgrades := TurretUpgradeRuntime.new()
	assert(upgrades.get_damage(1) == 1)
	assert(upgrades.apply_scalar(&"turret_damage_bonus", 1.0))
	assert(upgrades.apply_scalar(&"turret_damage_bonus", 1.0))
	assert(upgrades.get_damage(1) == 3)
	assert(upgrades.apply_scalar(&"turret_cooldown_multiplier", 0.85))
	assert(upgrades.apply_scalar(&"turret_cooldown_multiplier", 0.85))
	assert(is_equal_approx(upgrades.get_cooldown(0.8), 0.8 * 0.85 * 0.85))
	assert(upgrades.apply_scalar(&"turret_range_multiplier", 1.2))
	assert(upgrades.apply_scalar(&"turret_range_multiplier", 1.2))
	assert(is_equal_approx(upgrades.get_range(360.0), 360.0 * 1.2 * 1.2))


func _test_specializations() -> void:
	var heavy := TurretUpgradeRuntime.new()
	assert(heavy.apply_flag(&"turret_specialization_heavy"))
	assert(heavy.specialization_id == TurretUpgradeRuntime.HEAVY)
	assert(heavy.get_damage(1) == 2)
	assert(heavy.apply_flag(&"turret_heavy_piercing"))
	assert(heavy.apply_flag(&"turret_heavy_explosive_fifth"))
	assert(heavy.piercing_enabled)
	assert(heavy.explosive_fifth_enabled)

	var rapid := TurretUpgradeRuntime.new()
	assert(rapid.apply_flag(&"turret_specialization_rapid"))
	assert(rapid.specialization_id == TurretUpgradeRuntime.RAPID)
	assert(is_equal_approx(rapid.get_cooldown(0.8), 0.4))
	assert(rapid.apply_flag(&"turret_rapid_double_shot"))
	assert(rapid.apply_flag(&"turret_rapid_extra_fifth"))
	assert(rapid.double_shot_enabled)
	assert(rapid.extra_fifth_shot_enabled)

	var electric := TurretUpgradeRuntime.new()
	assert(electric.apply_flag(&"turret_specialization_electric"))
	assert(electric.specialization_id == TurretUpgradeRuntime.ELECTRIC)
	assert(electric.stun_enabled)
	assert(electric.apply_flag(&"turret_electric_chain"))
	assert(electric.apply_flag(&"turret_electric_orb_fifth"))
	assert(electric.chain_enabled)
	assert(electric.electric_orb_enabled)


func _test_catalog_prerequisites() -> void:
	assert(CATALOG.is_valid())
	var runtime := UpgradeRuntime.new()
	var post: UpgradeDefinition = CATALOG.get_definition(&"common_turret_post")
	var damage_basic: UpgradeDefinition = CATALOG.get_definition(
		&"turret_damage_basic"
	)
	var damage_advanced: UpgradeDefinition = CATALOG.get_definition(
		&"turret_damage_advanced"
	)
	assert(not CATALOG.is_available(damage_basic, runtime))
	assert(runtime.record_card(post))
	assert(CATALOG.is_available(damage_basic, runtime))
	assert(not CATALOG.is_available(damage_advanced, runtime))
	assert(runtime.record_card(damage_basic))
	assert(CATALOG.is_available(damage_advanced, runtime))

	assert(runtime.record_card(CATALOG.get_definition(&"turret_range_basic")))
	assert(runtime.is_branch_ready_for_specialization(&"turret"))
	assert(runtime.record_card(CATALOG.get_definition(
		&"turret_specialization_heavy"
	)))
	assert(CATALOG.is_available(
		CATALOG.get_definition(&"turret_heavy_piercing"),
		runtime
	))
	assert(not CATALOG.is_available(
		CATALOG.get_definition(&"turret_rapid_double_shot"),
		runtime
	))


func _test_independent_volley_counters() -> void:
	var first := TurretRuntime.new(1)
	var second := TurretRuntime.new(2)
	for _index: int in range(4):
		first.finish_shot(0.0)
	assert(first.is_fifth_volley())
	assert(not second.is_fifth_volley())
	second.finish_shot(0.0)
	assert(first.completed_volleys == 4)
	assert(second.completed_volleys == 1)
