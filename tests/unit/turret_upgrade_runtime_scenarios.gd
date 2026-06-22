extends SceneTree

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/turret_branch_upgrade_catalog.tres"
)
const BALANCE: TurretUpgradeBalance = preload(
	"res://resources/balance/turret_specialization_balance.tres"
)


func _init() -> void:
	_test_base_lines()
	_test_effect_validation()
	_test_specializations()
	_test_catalog_prerequisites()
	_test_independent_shot_and_volley_counters()
	_test_area_cards_are_active()
	_test_provisional_area_balance()
	print("Turret upgrade runtime scenarios passed")
	quit()


func _test_base_lines() -> void:
	var upgrades := TurretUpgradeRuntime.new()
	assert(upgrades.get_damage(1) == 1)
	assert(upgrades.apply_scalar(&"turret_damage_bonus", 1.0))
	assert(upgrades.apply_scalar(&"turret_damage_bonus", 1.0))
	assert(upgrades.get_damage(1) == 3)
	assert(upgrades.apply_scalar(&"turret_cooldown_reduction", 0.15))
	assert(upgrades.apply_scalar(&"turret_cooldown_reduction", 0.15))
	assert(is_equal_approx(upgrades.get_cooldown(0.8), 0.8 * 0.7))
	assert(upgrades.apply_scalar(&"turret_range_bonus_ratio", 0.2))
	assert(upgrades.apply_scalar(&"turret_range_bonus_ratio", 0.2))
	assert(is_equal_approx(upgrades.get_range(360.0), 360.0 * 1.4))


func _test_effect_validation() -> void:
	var upgrades := TurretUpgradeRuntime.new()
	var damage := UpgradeEffectDefinition.new()
	damage.effect_type = UpgradeEffectDefinition.EffectType.DOMAIN_SCALAR
	damage.target_id = &"turret_damage_bonus"
	damage.scalar_value = 1.0
	assert(upgrades.can_apply_effect(damage))
	damage.scalar_value = 0.0
	assert(not upgrades.can_apply_effect(damage))
	damage.scalar_value = -1.0
	assert(not upgrades.can_apply_effect(damage))
	damage.scalar_value = 0.5
	assert(not upgrades.can_apply_effect(damage))
	assert(not upgrades.apply_scalar(damage.target_id, damage.scalar_value))

	var heavy := UpgradeEffectDefinition.new()
	heavy.effect_type = UpgradeEffectDefinition.EffectType.DOMAIN_FLAG
	heavy.target_id = TurretUpgradeRuntime.HEAVY
	var explosion := UpgradeEffectDefinition.new()
	explosion.effect_type = UpgradeEffectDefinition.EffectType.DOMAIN_FLAG
	explosion.target_id = &"turret_heavy_explosive_fifth"
	assert(upgrades.can_apply_effect(heavy))
	assert(not upgrades.can_apply_effect(explosion))
	assert(upgrades.apply_flag(heavy.target_id))
	assert(not upgrades.can_apply_effect(heavy))
	assert(upgrades.can_apply_effect(explosion))
	assert(upgrades.apply_flag(explosion.target_id))
	assert(not upgrades.can_apply_effect(explosion))


func _test_specializations() -> void:
	var heavy := TurretUpgradeRuntime.new()
	assert(heavy.apply_flag(TurretUpgradeRuntime.HEAVY))
	assert(heavy.get_damage(1) == 2)
	assert(heavy.apply_flag(&"turret_heavy_piercing"))
	assert(heavy.apply_flag(&"turret_heavy_explosive_fifth"))
	assert(heavy.piercing_enabled)
	assert(heavy.heavy_explosive_fifth_enabled)
	assert(not heavy.apply_flag(TurretUpgradeRuntime.HEAVY))

	var rapid := TurretUpgradeRuntime.new()
	assert(rapid.apply_flag(TurretUpgradeRuntime.RAPID))
	assert(is_equal_approx(rapid.get_cooldown(0.8), 0.4))
	assert(rapid.apply_flag(&"turret_rapid_double_shot"))
	assert(rapid.apply_flag(&"turret_rapid_extra_fifth"))
	var rapid_runtime := TurretRuntime.new(1)
	assert(rapid.get_shots_per_next_volley(rapid_runtime) == 2)
	for _index: int in range(4):
		assert(rapid_runtime.begin_volley(2))
		rapid_runtime.begin_shot(1, 0.0)
		assert(not rapid_runtime.finish_shot(0.0))
		rapid_runtime.begin_shot(1, 0.0)
		assert(rapid_runtime.finish_shot(0.0))
	assert(rapid_runtime.is_next_volley_fifth())
	assert(rapid.get_shots_per_next_volley(rapid_runtime) == 3)

	var electric := TurretUpgradeRuntime.new()
	assert(electric.apply_flag(TurretUpgradeRuntime.ELECTRIC))
	assert(electric.stun_enabled)
	assert(electric.apply_flag(&"turret_electric_chain"))
	assert(electric.apply_flag(&"turret_electric_orb_fifth"))
	assert(electric.chain_enabled)
	assert(electric.electric_orb_fifth_enabled)
	assert(not electric.apply_flag(&"turret_heavy_piercing"))


func _test_catalog_prerequisites() -> void:
	assert(CATALOG.is_valid())
	var runtime := UpgradeRuntime.new()
	var post: UpgradeDefinition = CATALOG.get_definition(&"turret_post")
	var basic: UpgradeDefinition = CATALOG.get_definition(&"turret_damage_basic")
	assert(not CATALOG.is_available(basic, runtime))
	assert(runtime.record_card(post))
	assert(CATALOG.is_available(basic, runtime))
	assert(runtime.record_card(basic))
	assert(runtime.record_card(CATALOG.get_definition(&"turret_range_basic")))
	assert(runtime.is_branch_ready_for_specialization(&"turret"))
	assert(runtime.record_card(CATALOG.get_definition(
		&"turret_specialization_heavy"
	)))
	assert(CATALOG.is_available(
		CATALOG.get_definition(&"turret_heavy_piercing"),
		runtime
	))
	assert(CATALOG.is_available(
		CATALOG.get_definition(&"turret_heavy_explosive_fifth"),
		runtime
	))
	assert(not CATALOG.is_available(
		CATALOG.get_definition(&"turret_electric_orb_fifth"),
		runtime
	))


func _test_independent_shot_and_volley_counters() -> void:
	var first := TurretRuntime.new(1)
	var second := TurretRuntime.new(2)
	assert(first.begin_volley(2))
	first.begin_shot(10, 0.0)
	assert(not first.finish_shot(0.0))
	first.begin_shot(11, 0.0)
	assert(first.finish_shot(0.0))
	assert(first.completed_shots == 2)
	assert(first.completed_volleys == 1)
	assert(second.completed_shots == 0)
	assert(second.completed_volleys == 0)


func _test_area_cards_are_active() -> void:
	assert(CATALOG.get_definition(&"turret_heavy_explosive_fifth") != null)
	assert(CATALOG.get_definition(&"turret_electric_orb_fifth") != null)


func _test_provisional_area_balance() -> void:
	assert(BALANCE.is_valid())
	assert(BALANCE.heavy_explosion_damage == 1)
	assert(is_equal_approx(BALANCE.heavy_explosion_radius, 64.0))
	assert(BALANCE.electric_orb_damage == 4)
	assert(is_equal_approx(BALANCE.electric_orb_radius, 96.0))
