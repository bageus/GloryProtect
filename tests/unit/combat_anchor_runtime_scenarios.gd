extends SceneTree


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var runtime := CombatAnchorUpgradeRuntime.new()
	assert(runtime.can_apply_effect(_scalar(
		CombatAnchorUpgradeRuntime.OVERLOAD_BONUS_SECONDS,
		1.0
	)))
	assert(runtime.apply_scalar(
		CombatAnchorUpgradeRuntime.OVERLOAD_BONUS_SECONDS,
		1.0
	))
	assert(runtime.apply_scalar(
		CombatAnchorUpgradeRuntime.OVERLOAD_BONUS_SECONDS,
		1.0
	))
	assert(is_equal_approx(runtime.overload_bonus_seconds, 2.0))
	assert(runtime.apply_scalar(
		CombatAnchorUpgradeRuntime.INSTALL_SPEED_BONUS_RATIO,
		0.2
	))
	assert(runtime.apply_scalar(
		CombatAnchorUpgradeRuntime.INSTALL_SPEED_BONUS_RATIO,
		0.2
	))
	assert(is_equal_approx(runtime.install_speed_bonus_ratio, 0.4))

	assert(not runtime.apply_flag(
		CombatAnchorUpgradeRuntime.PERIODIC_ELECTRIC_ADVANCED
	))
	assert(runtime.apply_flag(CombatAnchorUpgradeRuntime.PERIODIC_ELECTRIC))
	assert(runtime.apply_flag(
		CombatAnchorUpgradeRuntime.PERIODIC_ELECTRIC_ADVANCED
	))
	assert(runtime.periodic_electric_enabled)
	assert(runtime.periodic_electric_advanced)
	assert(runtime.apply_flag(CombatAnchorUpgradeRuntime.INSTANT_REMOVE_ALL))

	assert(runtime.apply_flag(CombatAnchorUpgradeRuntime.STRONG))
	assert(runtime.has_strong_specialization())
	assert(not runtime.apply_flag(CombatAnchorUpgradeRuntime.ELECTRIC))
	assert(not runtime.apply_flag(CombatAnchorUpgradeRuntime.TRAP))
	assert(runtime.apply_flag(CombatAnchorUpgradeRuntime.STRONG_SECOND_INSTALL))
	assert(runtime.apply_flag(CombatAnchorUpgradeRuntime.STRONG_CLIMBER_FALL))
	assert(not runtime.apply_flag(CombatAnchorUpgradeRuntime.ELECTRIC_DROP))

	runtime.reset()
	assert(is_zero_approx(runtime.overload_bonus_seconds))
	assert(is_zero_approx(runtime.install_speed_bonus_ratio))
	assert(not runtime.periodic_electric_enabled)
	assert(not runtime.instant_remove_all_enabled)
	assert(runtime.specialization_id == &"")
	assert(runtime.apply_flag(CombatAnchorUpgradeRuntime.ELECTRIC))
	assert(runtime.apply_flag(CombatAnchorUpgradeRuntime.ELECTRIC_DROP))
	assert(not runtime.apply_flag(CombatAnchorUpgradeRuntime.TRAP_ATTACH_EXPLOSION))

	var balance := CombatAnchorBalance.new()
	assert(balance.is_valid())
	assert(is_equal_approx(balance.get_periodic_interval(false), 4.0))
	assert(is_equal_approx(balance.get_periodic_interval(true), 2.0))

	print("Combat anchor runtime scenarios passed")
	quit()


func _scalar(target_id: StringName, value: float) -> UpgradeEffectDefinition:
	var effect := UpgradeEffectDefinition.new()
	effect.effect_type = UpgradeEffectDefinition.EffectType.DOMAIN_SCALAR
	effect.target_id = target_id
	effect.scalar_value = value
	return effect
