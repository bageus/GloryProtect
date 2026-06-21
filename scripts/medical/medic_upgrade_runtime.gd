class_name MedicUpgradeRuntime
extends RefCounted

const FIELD: StringName = &"medic_specialization_field"
const STIMULANT: StringName = &"medic_specialization_stimulant"
const PROTECTIVE: StringName = &"medic_specialization_protective"

var heal_amount_bonus: int = 0
var heal_speed_bonus_ratio: float = 0.0
var heal_range_bonus_ratio: float = 0.0
var role_health_bonus: int = 0
var role_armor_bonus: int = 0
var specialization_id: StringName = &""
var field_combat_enabled: bool = false
var field_emergency_enabled: bool = false
var stimulant_enabled: bool = false
var revival_enabled: bool = false
var protective_armor_enabled: bool = false
var protective_full_guard_enabled: bool = false
var chain_therapy_enabled: bool = false


func reset() -> void:
	heal_amount_bonus = 0
	heal_speed_bonus_ratio = 0.0
	heal_range_bonus_ratio = 0.0
	role_health_bonus = 0
	role_armor_bonus = 0
	specialization_id = &""
	field_combat_enabled = false
	field_emergency_enabled = false
	stimulant_enabled = false
	revival_enabled = false
	protective_armor_enabled = false
	protective_full_guard_enabled = false
	chain_therapy_enabled = false


func can_apply_effect(effect: UpgradeEffectDefinition) -> bool:
	if effect == null:
		return false
	match effect.effect_type:
		UpgradeEffectDefinition.EffectType.DOMAIN_SCALAR:
			return _can_apply_scalar(effect.target_id, effect.scalar_value)
		UpgradeEffectDefinition.EffectType.DOMAIN_FLAG:
			return _can_apply_flag(effect.target_id)
	return false


func apply_scalar(target_id: StringName, value: float) -> bool:
	if not _can_apply_scalar(target_id, value):
		return false
	match target_id:
		&"medic_heal_amount_bonus":
			heal_amount_bonus += roundi(value)
			return true
		&"medic_heal_speed_bonus_ratio":
			heal_speed_bonus_ratio += value
			return true
		&"medic_heal_range_bonus_ratio":
			heal_range_bonus_ratio += value
			return true
		&"medic_role_health_bonus":
			role_health_bonus += roundi(value)
			return true
		&"medic_role_armor_bonus":
			role_armor_bonus += roundi(value)
			return true
	return false


func apply_flag(target_id: StringName) -> bool:
	if not _can_apply_flag(target_id):
		return false
	match target_id:
		FIELD:
			specialization_id = FIELD
			return true
		STIMULANT:
			specialization_id = STIMULANT
			stimulant_enabled = true
			return true
		PROTECTIVE:
			specialization_id = PROTECTIVE
			protective_armor_enabled = true
			protective_full_guard_enabled = true
			return true
		&"medic_field_combat":
			field_combat_enabled = true
			return true
		&"medic_field_emergency":
			field_emergency_enabled = true
			return true
		&"medic_stimulant_revival":
			revival_enabled = true
			return true
		&"medic_protective_chain":
			chain_therapy_enabled = true
			return true
	return false


func get_heal_amount(base_amount: int) -> int:
	return maxi(1, base_amount + heal_amount_bonus)


func get_heal_interval(base_interval: float) -> float:
	return maxf(0.01, base_interval / (1.0 + heal_speed_bonus_ratio))


func get_heal_range(base_range: float) -> float:
	return maxf(0.0, base_range * (1.0 + heal_range_bonus_ratio))


func _can_apply_scalar(target_id: StringName, value: float) -> bool:
	match target_id:
		&"medic_heal_amount_bonus", &"medic_role_health_bonus", &"medic_role_armor_bonus":
			return value >= 1.0 and is_equal_approx(value, float(roundi(value)))
		&"medic_heal_speed_bonus_ratio", &"medic_heal_range_bonus_ratio":
			return value > 0.0
	return false


func _can_apply_flag(target_id: StringName) -> bool:
	match target_id:
		FIELD, STIMULANT, PROTECTIVE:
			return specialization_id == &""
		&"medic_field_combat":
			return specialization_id == FIELD and not field_combat_enabled
		&"medic_field_emergency":
			return specialization_id == FIELD and not field_emergency_enabled
		&"medic_stimulant_revival":
			return specialization_id == STIMULANT and not revival_enabled
		&"medic_protective_chain":
			return specialization_id == PROTECTIVE and not chain_therapy_enabled
	return false
