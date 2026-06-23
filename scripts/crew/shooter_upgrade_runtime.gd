class_name ShooterUpgradeRuntime
extends RefCounted

const SNIPER: StringName = &"sniper"
const AIR_HUNTER: StringName = &"air_hunter"
const ANCHOR_HUNTER: StringName = &"anchor_hunter"

var role_unlocked: bool = false
var damage_bonus: int = 0
var range_multiplier: float = 1.0
var cooldown_multiplier: float = 1.0
var specialization_id: StringName = &""
var piercing_enabled: bool = false
var sniper_multi_pierce: bool = false
var sniper_explosive_fifth: bool = false
var air_triple_shot: bool = false
var air_mark_fifth: bool = false
var anchor_triple_shot: bool = false
var anchor_knockdown_fifth: bool = false


func reset() -> void:
	role_unlocked = false
	damage_bonus = 0
	range_multiplier = 1.0
	cooldown_multiplier = 1.0
	specialization_id = &""
	piercing_enabled = false
	sniper_multi_pierce = false
	sniper_explosive_fifth = false
	air_triple_shot = false
	air_mark_fifth = false
	anchor_triple_shot = false
	anchor_knockdown_fifth = false


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
		&"shooter_damage_bonus":
			damage_bonus += roundi(value)
			return true
		&"shooter_range_multiplier":
			range_multiplier += value - 1.0
			return true
		&"shooter_cooldown_multiplier":
			cooldown_multiplier = maxf(
				0.01,
				cooldown_multiplier - (1.0 - value)
			)
			return true
	return false


func apply_flag(target_id: StringName) -> bool:
	if not _can_apply_flag(target_id):
		return false
	match target_id:
		&"shooter_role_unlocked":
			role_unlocked = true
			return true
		&"shooter_piercing_bolt":
			piercing_enabled = true
			return true
		&"shooter_specialization_sniper":
			specialization_id = SNIPER
			damage_bonus += 1
			range_multiplier += 0.1
			return true
		&"shooter_sniper_multi_pierce":
			sniper_multi_pierce = true
			return true
		&"shooter_sniper_explosive_fifth":
			sniper_explosive_fifth = true
			return true
		&"shooter_specialization_air_hunter":
			specialization_id = AIR_HUNTER
			return true
		&"shooter_air_triple_shot":
			air_triple_shot = true
			return true
		&"shooter_air_mark_fifth":
			air_mark_fifth = true
			return true
		&"shooter_specialization_anchor_hunter":
			specialization_id = ANCHOR_HUNTER
			return true
		&"shooter_anchor_triple_shot":
			anchor_triple_shot = true
			return true
		&"shooter_anchor_knockdown_fifth":
			anchor_knockdown_fifth = true
			return true
	return false


func get_damage(
	base_damage: int,
	target_domain: int,
	target_is_climbing: bool = false
) -> int:
	var result: int = maxi(1, base_damage + damage_bonus)
	if (
		specialization_id == AIR_HUNTER
		and target_domain == EnemyBehaviorComponent.TargetDomain.AIR
	):
		result += 1
	if specialization_id == ANCHOR_HUNTER and target_is_climbing:
		result += 1
	return result


func get_range(base_range: float) -> float:
	return maxf(1.0, base_range * range_multiplier)


func get_cooldown(base_cooldown: float) -> float:
	return maxf(0.01, base_cooldown * cooldown_multiplier)


func _can_apply_scalar(target_id: StringName, value: float) -> bool:
	match target_id:
		&"shooter_damage_bonus":
			return (
				value >= 1.0
				and is_equal_approx(value, float(roundi(value)))
			)
		&"shooter_range_multiplier":
			return value > 1.0
		&"shooter_cooldown_multiplier":
			return value > 0.0 and value < 1.0
	return false


func _can_apply_flag(target_id: StringName) -> bool:
	match target_id:
		&"shooter_role_unlocked":
			return not role_unlocked
		&"shooter_piercing_bolt":
			return not piercing_enabled
		&"shooter_specialization_sniper", \
		&"shooter_specialization_air_hunter", \
		&"shooter_specialization_anchor_hunter":
			return specialization_id == &""
		&"shooter_sniper_multi_pierce":
			return specialization_id == SNIPER and not sniper_multi_pierce
		&"shooter_sniper_explosive_fifth":
			return specialization_id == SNIPER and not sniper_explosive_fifth
		&"shooter_air_triple_shot":
			return specialization_id == AIR_HUNTER and not air_triple_shot
		&"shooter_air_mark_fifth":
			return specialization_id == AIR_HUNTER and not air_mark_fifth
		&"shooter_anchor_triple_shot":
			return specialization_id == ANCHOR_HUNTER and not anchor_triple_shot
		&"shooter_anchor_knockdown_fifth":
			return (
				specialization_id == ANCHOR_HUNTER
				and not anchor_knockdown_fifth
			)
	return false
