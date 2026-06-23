extends SceneTree

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/shooter_upgrade_catalog.tres"
)


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	_test_effect_validation()
	_test_effect_applier_routing()
	_test_base_lines()
	_test_specializations()
	_test_reset()
	print("Shooter upgrade runtime scenarios passed")
	quit()


func _test_effect_validation() -> void:
	var runtime := ShooterUpgradeRuntime.new()
	assert(not runtime.can_apply_effect(null))
	assert(not runtime.can_apply_effect(
		_make_scalar_effect(&"shooter_damage_bonus", 0.5)
	))
	assert(not runtime.can_apply_effect(
		_make_scalar_effect(&"shooter_damage_bonus", 1.5)
	))
	assert(runtime.can_apply_effect(
		_make_scalar_effect(&"shooter_damage_bonus", 1.0)
	))
	assert(not runtime.can_apply_effect(
		_make_scalar_effect(&"shooter_range_multiplier", 1.0)
	))
	assert(runtime.can_apply_effect(
		_make_scalar_effect(&"shooter_range_multiplier", 1.2)
	))
	assert(not runtime.can_apply_effect(
		_make_scalar_effect(&"shooter_cooldown_multiplier", 1.0)
	))
	assert(runtime.can_apply_effect(
		_make_scalar_effect(&"shooter_cooldown_multiplier", 0.85)
	))
	var unlock := _make_flag_effect(&"shooter_role_unlocked")
	assert(runtime.can_apply_effect(unlock))
	assert(runtime.apply_flag(unlock.target_id))
	assert(not runtime.can_apply_effect(unlock))
	var air_extra := _make_flag_effect(&"shooter_air_triple_shot")
	assert(not runtime.can_apply_effect(air_extra))
	var air_specialization := _make_flag_effect(
		&"shooter_specialization_air_hunter"
	)
	assert(runtime.can_apply_effect(air_specialization))
	assert(runtime.apply_flag(air_specialization.target_id))
	assert(not runtime.can_apply_effect(air_specialization))
	assert(not runtime.can_apply_effect(_make_flag_effect(
		&"shooter_specialization_sniper"
	)))
	assert(runtime.can_apply_effect(air_extra))
	assert(runtime.apply_flag(air_extra.target_id))
	assert(not runtime.can_apply_effect(air_extra))


func _test_effect_applier_routing() -> void:
	var buildables := BuildableInventory.new()
	var runtime := UpgradeRuntime.new()
	var crew := CrewManager.new()
	var applier := UpgradeEffectApplier.new()
	applier.configure(buildables, runtime, crew)
	var unlock: UpgradeDefinition = CATALOG.get_definition(&"shooter_unlock")
	var air_specialization: UpgradeDefinition = CATALOG.get_definition(
		&"shooter_specialization_air_hunter"
	)
	var air_extra: UpgradeDefinition = CATALOG.get_definition(
		&"shooter_air_triple_shot"
	)
	assert(applier.can_apply(unlock))
	assert(applier.apply_effect(unlock))
	assert(not applier.can_apply(unlock))
	assert(not applier.can_apply(air_extra))
	assert(applier.can_apply(air_specialization))
	assert(applier.apply_effect(air_specialization))
	assert(not applier.can_apply(air_specialization))
	assert(applier.can_apply(air_extra))
	assert(applier.apply_effect(air_extra))
	assert(not applier.can_apply(air_extra))
	buildables.free()
	crew.free()


func _test_base_lines() -> void:
	var runtime := ShooterUpgradeRuntime.new()
	assert(not runtime.role_unlocked)
	assert(runtime.apply_flag(&"shooter_role_unlocked"))
	assert(runtime.role_unlocked)
	assert(runtime.apply_scalar(&"shooter_damage_bonus", 1.0))
	assert(runtime.apply_scalar(&"shooter_damage_bonus", 1.0))
	assert(
		runtime.get_damage(
			1,
			EnemyBehaviorComponent.TargetDomain.GROUND
		) == 3
	)
	assert(runtime.apply_scalar(&"shooter_range_multiplier", 1.2))
	assert(runtime.apply_scalar(&"shooter_range_multiplier", 1.2))
	assert(is_equal_approx(runtime.get_range(420.0), 420.0 * 1.4))
	assert(runtime.apply_scalar(&"shooter_cooldown_multiplier", 0.85))
	assert(runtime.apply_scalar(&"shooter_cooldown_multiplier", 0.85))
	assert(is_equal_approx(runtime.get_cooldown(1.0), 0.7))
	assert(runtime.apply_flag(&"shooter_piercing_bolt"))
	assert(runtime.piercing_enabled)


func _test_specializations() -> void:
	var sniper := ShooterUpgradeRuntime.new()
	assert(sniper.apply_scalar(&"shooter_range_multiplier", 1.2))
	assert(sniper.apply_scalar(&"shooter_range_multiplier", 1.2))
	assert(sniper.apply_flag(&"shooter_specialization_sniper"))
	assert(sniper.specialization_id == ShooterUpgradeRuntime.SNIPER)
	assert(
		sniper.get_damage(
			1,
			EnemyBehaviorComponent.TargetDomain.GROUND
		) == 2
	)
	assert(is_equal_approx(sniper.get_range(100.0), 150.0))
	assert(not sniper.apply_flag(&"shooter_specialization_air_hunter"))

	var air := ShooterUpgradeRuntime.new()
	assert(air.apply_flag(&"shooter_specialization_air_hunter"))
	assert(air.get_damage(1, EnemyBehaviorComponent.TargetDomain.AIR) == 2)
	assert(
		air.get_damage(
			1,
			EnemyBehaviorComponent.TargetDomain.GROUND
		) == 1
	)
	assert(air.apply_flag(&"shooter_air_triple_shot"))
	assert(air.apply_flag(&"shooter_air_mark_fifth"))
	assert(not air.apply_flag(&"shooter_sniper_multi_pierce"))

	var anchor := ShooterUpgradeRuntime.new()
	assert(anchor.apply_flag(&"shooter_specialization_anchor_hunter"))
	assert(anchor.get_damage(
		1,
		EnemyBehaviorComponent.TargetDomain.GROUND,
		true
	) == 2)
	assert(anchor.get_damage(
		1,
		EnemyBehaviorComponent.TargetDomain.GROUND,
		false
	) == 1)
	assert(anchor.apply_flag(&"shooter_anchor_triple_shot"))
	assert(anchor.apply_flag(&"shooter_anchor_knockdown_fifth"))
	assert(not anchor.apply_flag(&"shooter_air_mark_fifth"))


func _test_reset() -> void:
	var runtime := ShooterUpgradeRuntime.new()
	runtime.apply_flag(&"shooter_role_unlocked")
	runtime.apply_scalar(&"shooter_damage_bonus", 2.0)
	runtime.apply_scalar(&"shooter_range_multiplier", 1.2)
	runtime.apply_scalar(&"shooter_cooldown_multiplier", 0.85)
	runtime.apply_flag(&"shooter_specialization_sniper")
	runtime.apply_flag(&"shooter_sniper_multi_pierce")
	runtime.reset()
	assert(not runtime.role_unlocked)
	assert(runtime.damage_bonus == 0)
	assert(is_equal_approx(runtime.range_multiplier, 1.0))
	assert(is_equal_approx(runtime.cooldown_multiplier, 1.0))
	assert(runtime.specialization_id == &"")
	assert(not runtime.sniper_multi_pierce)


func _make_scalar_effect(
	target_id: StringName,
	value: float
) -> UpgradeEffectDefinition:
	var effect := UpgradeEffectDefinition.new()
	effect.effect_type = UpgradeEffectDefinition.EffectType.DOMAIN_SCALAR
	effect.target_id = target_id
	effect.scalar_value = value
	return effect


func _make_flag_effect(target_id: StringName) -> UpgradeEffectDefinition:
	var effect := UpgradeEffectDefinition.new()
	effect.effect_type = UpgradeEffectDefinition.EffectType.DOMAIN_FLAG
	effect.target_id = target_id
	return effect
