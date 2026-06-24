class_name ShieldCoreUpgradeRuntime
extends RefCounted

const CAPACITY_BONUS_RATIO: StringName = &"shield_capacity_bonus_ratio"
const RECHARGE_BONUS_RATIO: StringName = &"shield_recharge_bonus_ratio"
const CONTACT_WIDTH_BONUS_RATIO: StringName = &"shield_contact_width_bonus_ratio"

const FOCUSED: StringName = &"shield_specialization_focused"
const DISTRIBUTED: StringName = &"shield_specialization_distributed"
const SURGE: StringName = &"shield_specialization_surge"

var capacity_bonus_ratio: float = 0.0
var recharge_bonus_ratio: float = 0.0
var contact_width_bonus_ratio: float = 0.0
var specialization_id: StringName = &""


func reset() -> void:
	capacity_bonus_ratio = 0.0
	recharge_bonus_ratio = 0.0
	contact_width_bonus_ratio = 0.0
	specialization_id = &""


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
		CAPACITY_BONUS_RATIO:
			capacity_bonus_ratio += value
			return true
		RECHARGE_BONUS_RATIO:
			recharge_bonus_ratio += value
			return true
		CONTACT_WIDTH_BONUS_RATIO:
			contact_width_bonus_ratio += value
			return true
	return false


func apply_flag(target_id: StringName) -> bool:
	if not _can_apply_flag(target_id):
		return false
	specialization_id = target_id
	return true


func has_focused_specialization() -> bool:
	return specialization_id == FOCUSED


func has_distributed_specialization() -> bool:
	return specialization_id == DISTRIBUTED


func has_surge_specialization() -> bool:
	return specialization_id == SURGE


func _can_apply_scalar(target_id: StringName, value: float) -> bool:
	if value <= 0.0:
		return false
	return target_id in [
		CAPACITY_BONUS_RATIO,
		RECHARGE_BONUS_RATIO,
		CONTACT_WIDTH_BONUS_RATIO,
	]


func _can_apply_flag(target_id: StringName) -> bool:
	return specialization_id == &"" and target_id in [FOCUSED, DISTRIBUTED, SURGE]
