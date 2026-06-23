extends SceneTree

const BALANCE: AnchorlessControlBalance = preload(
	"res://resources/balance/anchorless_control_balance.tres"
)


func _init() -> void:
	_test_base_lines()
	_test_effect_validation()
	_test_specialization_locking()
	_test_balance()
	print("Anchorless control runtime scenarios passed")
	quit()


func _test_base_lines() -> void:
	var runtime := AnchorlessControlUpgradeRuntime.new()
	assert(runtime.apply_scalar(
		AnchorlessControlUpgradeRuntime.STEERING_FORCE_BONUS,
		0.1
	))
	assert(runtime.apply_scalar(
		AnchorlessControlUpgradeRuntime.STEERING_FORCE_BONUS,
		0.1
	))
	assert(is_equal_approx(runtime.steering_force_bonus_ratio, 0.2))
	assert(runtime.apply_scalar(
		AnchorlessControlUpgradeRuntime.WIND_REDUCTION,
		0.1
	))
	assert(runtime.apply_scalar(
		AnchorlessControlUpgradeRuntime.WIND_REDUCTION,
		0.1
	))
	assert(is_equal_approx(runtime.wind_reduction_ratio, 0.2))
	assert(runtime.apply_scalar(
		AnchorlessControlUpgradeRuntime.RELEASE_DRAG_BONUS,
		0.2
	))
	assert(runtime.apply_scalar(
		AnchorlessControlUpgradeRuntime.RELEASE_DRAG_BONUS,
		0.2
	))
	assert(is_equal_approx(runtime.release_drag_bonus_ratio, 0.4))
	assert(runtime.apply_flag(AnchorlessControlUpgradeRuntime.AUTO_STEERING))
	assert(runtime.automatic_steering_enabled)


func _test_effect_validation() -> void:
	var runtime := AnchorlessControlUpgradeRuntime.new()
	var effect := UpgradeEffectDefinition.new()
	effect.effect_type = UpgradeEffectDefinition.EffectType.DOMAIN_SCALAR
	effect.target_id = AnchorlessControlUpgradeRuntime.STEERING_FORCE_BONUS
	effect.scalar_value = 0.1
	assert(runtime.can_apply_effect(effect))
	effect.scalar_value = 0.0
	assert(not runtime.can_apply_effect(effect))
	effect.scalar_value = -0.1
	assert(not runtime.can_apply_effect(effect))
	effect.scalar_value = 0.1
	effect.target_id = &"anchorless_unknown"
	assert(not runtime.can_apply_effect(effect))


func _test_specialization_locking() -> void:
	var runtime := AnchorlessControlUpgradeRuntime.new()
	assert(runtime.apply_flag(AnchorlessControlUpgradeRuntime.SPEED))
	assert(not runtime.apply_flag(AnchorlessControlUpgradeRuntime.PRECISE))
	assert(not runtime.apply_flag(AnchorlessControlUpgradeRuntime.POWERFUL))
	assert(runtime.apply_flag(
		AnchorlessControlUpgradeRuntime.SPEED_LONG_FLIGHT_RESTORE
	))
	assert(runtime.apply_flag(AnchorlessControlUpgradeRuntime.SPEED_FRONT_SWEEP))
	assert(not runtime.apply_flag(
		AnchorlessControlUpgradeRuntime.PRECISE_RECHARGE
	))
	assert(not runtime.apply_flag(
		AnchorlessControlUpgradeRuntime.POWERFUL_GROUND_CORE
	))

	runtime.reset()
	assert(runtime.specialization_id == &"")
	assert(runtime.apply_flag(AnchorlessControlUpgradeRuntime.POWERFUL))
	assert(runtime.apply_flag(
		AnchorlessControlUpgradeRuntime.POWERFUL_GROUND_CORE
	))
	assert(runtime.apply_flag(
		AnchorlessControlUpgradeRuntime.POWERFUL_PLATFORM_CORE
	))


func _test_balance() -> void:
	assert(BALANCE.is_valid())
	assert(is_equal_approx(BALANCE.precise_inertia_reduction_ratio, 0.25))
	assert(is_equal_approx(BALANCE.precise_recharge_bonus_ratio, 0.25))
	assert(is_equal_approx(BALANCE.speed_acceleration_bonus_ratio, 0.15))
	assert(is_equal_approx(BALANCE.speed_max_speed_bonus_ratio, 0.15))
	assert(is_equal_approx(BALANCE.long_flight_restore_ratio, 0.10))
	assert(BALANCE.anchor_discharge_damage == 1)
	assert(BALANCE.core_pulse_damage == 2)
