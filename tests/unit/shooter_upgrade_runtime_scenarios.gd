extends SceneTree


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	_test_base_lines()
	_test_specializations()
	_test_reset()
	print("Shooter upgrade runtime scenarios passed")
	quit()


func _test_base_lines() -> void:
	var runtime := ShooterUpgradeRuntime.new()
	assert(not runtime.role_unlocked)
	assert(runtime.apply_flag(&"shooter_role_unlocked"))
	assert(runtime.role_unlocked)
	assert(runtime.apply_scalar(&"shooter_damage_bonus", 1.0))
	assert(runtime.apply_scalar(&"shooter_damage_bonus", 1.0))
	assert(runtime.get_damage(1, EnemyBehaviorComponent.TargetDomain.GROUND) == 3)
	assert(runtime.apply_scalar(&"shooter_range_multiplier", 1.2))
	assert(runtime.apply_scalar(&"shooter_range_multiplier", 1.2))
	assert(is_equal_approx(runtime.get_range(420.0), 420.0 * 1.2 * 1.2))
	assert(runtime.apply_scalar(&"shooter_cooldown_multiplier", 0.85))
	assert(runtime.apply_scalar(&"shooter_cooldown_multiplier", 0.85))
	assert(is_equal_approx(runtime.get_cooldown(1.0), 0.85 * 0.85))
	assert(runtime.apply_flag(&"shooter_piercing_bolt"))
	assert(runtime.piercing_enabled)


func _test_specializations() -> void:
	var sniper := ShooterUpgradeRuntime.new()
	assert(sniper.apply_flag(&"shooter_specialization_sniper"))
	assert(sniper.specialization_id == ShooterUpgradeRuntime.SNIPER)
	assert(sniper.get_damage(1, EnemyBehaviorComponent.TargetDomain.GROUND) == 2)
	assert(is_equal_approx(sniper.get_range(100.0), 110.0))
	assert(not sniper.apply_flag(&"shooter_specialization_air_hunter"))

	var air := ShooterUpgradeRuntime.new()
	assert(air.apply_flag(&"shooter_specialization_air_hunter"))
	assert(air.get_damage(1, EnemyBehaviorComponent.TargetDomain.AIR) == 2)
	assert(air.get_damage(1, EnemyBehaviorComponent.TargetDomain.GROUND) == 1)
	assert(air.apply_flag(&"shooter_air_triple_shot"))
	assert(air.apply_flag(&"shooter_air_mark_fifth"))

	var anchor := ShooterUpgradeRuntime.new()
	assert(anchor.apply_flag(&"shooter_specialization_anchor_hunter"))
	assert(anchor.get_damage(1, EnemyBehaviorComponent.TargetDomain.GROUND) == 2)
	assert(anchor.apply_flag(&"shooter_anchor_triple_shot"))
	assert(anchor.apply_flag(&"shooter_anchor_knockdown_fifth"))


func _test_reset() -> void:
	var runtime := ShooterUpgradeRuntime.new()
	runtime.apply_flag(&"shooter_role_unlocked")
	runtime.apply_scalar(&"shooter_damage_bonus", 2.0)
	runtime.apply_flag(&"shooter_specialization_sniper")
	runtime.apply_flag(&"shooter_sniper_multi_pierce")
	runtime.reset()
	assert(not runtime.role_unlocked)
	assert(runtime.damage_bonus == 0)
	assert(runtime.specialization_id == &"")
	assert(not runtime.sniper_multi_pierce)
