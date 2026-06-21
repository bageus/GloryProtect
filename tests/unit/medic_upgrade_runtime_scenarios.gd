extends SceneTree

const BALANCE: MedicUpgradeBalance = preload(
	"res://resources/balance/medic_specialization_balance.tres"
)


func _init() -> void:
	_test_base_lines()
	_test_effect_validation()
	_test_specialization_locking()
	_test_provisional_balance()
	print("Medic upgrade runtime scenarios passed")
	quit()


func _test_base_lines() -> void:
	var runtime := MedicUpgradeRuntime.new()
	assert(runtime.get_heal_amount(1) == 1)
	assert(runtime.apply_scalar(&"medic_heal_amount_bonus", 1.0))
	assert(runtime.apply_scalar(&"medic_heal_amount_bonus", 1.0))
	assert(runtime.get_heal_amount(1) == 3)

	assert(runtime.apply_scalar(&"medic_heal_speed_bonus_ratio", 0.2))
	assert(runtime.apply_scalar(&"medic_heal_speed_bonus_ratio", 0.2))
	assert(is_equal_approx(runtime.get_heal_interval(5.0), 5.0 / 1.4))

	assert(runtime.apply_scalar(&"medic_heal_range_bonus_ratio", 0.15))
	assert(runtime.apply_scalar(&"medic_heal_range_bonus_ratio", 0.15))
	assert(is_equal_approx(runtime.get_heal_range(18.0), 18.0 * 1.3))

	assert(runtime.apply_scalar(&"medic_role_health_bonus", 2.0))
	assert(runtime.apply_scalar(&"medic_role_armor_bonus", 2.0))
	assert(runtime.role_health_bonus == 2)
	assert(runtime.role_armor_bonus == 2)


func _test_effect_validation() -> void:
	var runtime := MedicUpgradeRuntime.new()
	var effect := UpgradeEffectDefinition.new()
	effect.effect_type = UpgradeEffectDefinition.EffectType.DOMAIN_SCALAR
	effect.target_id = &"medic_heal_amount_bonus"
	effect.scalar_value = 1.0
	assert(runtime.can_apply_effect(effect))
	effect.scalar_value = 0.5
	assert(not runtime.can_apply_effect(effect))
	effect.scalar_value = 0.0
	assert(not runtime.can_apply_effect(effect))
	effect.target_id = &"medic_unknown"
	effect.scalar_value = 1.0
	assert(not runtime.can_apply_effect(effect))


func _test_specialization_locking() -> void:
	var runtime := MedicUpgradeRuntime.new()
	assert(runtime.apply_flag(MedicUpgradeRuntime.FIELD))
	assert(not runtime.apply_flag(MedicUpgradeRuntime.STIMULANT))
	assert(not runtime.apply_flag(MedicUpgradeRuntime.PROTECTIVE))
	assert(runtime.apply_flag(&"medic_field_combat"))
	assert(runtime.apply_flag(&"medic_field_emergency"))
	assert(not runtime.apply_flag(&"medic_field_combat"))
	assert(not runtime.apply_flag(&"medic_stimulant_revival"))

	runtime.reset()
	assert(runtime.apply_flag(MedicUpgradeRuntime.PROTECTIVE))
	assert(runtime.protective_armor_enabled)
	assert(runtime.protective_full_guard_enabled)
	assert(runtime.apply_flag(&"medic_protective_chain"))
	assert(runtime.chain_therapy_enabled)


func _test_provisional_balance() -> void:
	assert(BALANCE.is_valid())
	assert(BALANCE.field_attack.attack_type == MedicAttackDefinition.AttackType.MELEE_SWORD)
	assert(BALANCE.field_attack.damage_bonus == 1)
	assert(is_equal_approx(BALANCE.emergency_heal_interval_multiplier, 0.5))
	assert(is_equal_approx(BALANCE.chain_heal_ratio, 0.5))
	assert(is_equal_approx(BALANCE.revival_cooldown, 60.0))
