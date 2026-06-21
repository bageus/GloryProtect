class_name TurretUpgradeRuntime
extends RefCounted

const HEAVY: StringName = &"turret_specialization_heavy"
const RAPID: StringName = &"turret_specialization_rapid"
const ELECTRIC: StringName = &"turret_specialization_electric"

var damage_bonus: int = 0
var cooldown_reduction: float = 0.0
var range_bonus_ratio: float = 0.0
var specialization_id: StringName = &""
var piercing_enabled: bool = false
var double_shot_enabled: bool = false
var extra_fifth_volley_shot_enabled: bool = false
var stun_enabled: bool = false
var chain_enabled: bool = false


func reset() -> void:
	damage_bonus = 0
	cooldown_reduction = 0.0
	range_bonus_ratio = 0.0
	specialization_id = &""
	piercing_enabled = false
	double_shot_enabled = false
	extra_fifth_volley_shot_enabled = false
	stun_enabled = false
	chain_enabled = false


func can_apply_effect(effect: UpgradeEffectDefinition) -> bool:
	if effect == null:
		return false
	match effect.effect_type:
		UpgradeEffectDefinition.EffectType.DOMAIN_SCALAR:
			return effect.target_id in [
				&"turret_damage_bonus",
				&"turret_cooldown_reduction",
				&"turret_range_bonus_ratio",
			]
		UpgradeEffectDefinition.EffectType.DOMAIN_FLAG:
			return _can_apply_flag(effect.target_id)
	return false


func apply_scalar(target_id: StringName, value: float) -> bool:
	match target_id:
		&"turret_damage_bonus":
			damage_bonus += roundi(value)
			return true
		&"turret_cooldown_reduction":
			if value <= 0.0:
				return false
			cooldown_reduction = minf(0.95, cooldown_reduction + value)
			return true
		&"turret_range_bonus_ratio":
			if value <= 0.0:
				return false
			range_bonus_ratio += value
			return true
	return false


func apply_flag(target_id: StringName) -> bool:
	if not _can_apply_flag(target_id):
		return false
	match target_id:
		HEAVY:
			specialization_id = HEAVY
			damage_bonus += 1
			return true
		RAPID:
			specialization_id = RAPID
			cooldown_reduction = minf(0.95, cooldown_reduction + 0.5)
			return true
		ELECTRIC:
			specialization_id = ELECTRIC
			stun_enabled = true
			return true
		&"turret_heavy_piercing":
			piercing_enabled = true
			return true
		&"turret_rapid_double_shot":
			double_shot_enabled = true
			return true
		&"turret_rapid_extra_fifth":
			extra_fifth_volley_shot_enabled = true
			return true
		&"turret_electric_chain":
			chain_enabled = true
			return true
	return false


func get_damage(base_damage: int) -> int:
	return maxi(1, base_damage + damage_bonus)


func get_cooldown(base_cooldown: float) -> float:
	return maxf(0.0, base_cooldown * (1.0 - cooldown_reduction))


func get_range(base_range: float) -> float:
	return maxf(0.0, base_range * (1.0 + range_bonus_ratio))


func get_shots_per_next_volley(runtime: TurretRuntime) -> int:
	var result: int = 2 if double_shot_enabled else 1
	if extra_fifth_volley_shot_enabled and runtime.is_next_volley_fifth():
		result += 1
	return result


func _can_apply_flag(target_id: StringName) -> bool:
	match target_id:
		HEAVY, RAPID, ELECTRIC:
			return specialization_id == &""
		&"turret_heavy_piercing":
			return specialization_id == HEAVY and not piercing_enabled
		&"turret_rapid_double_shot":
			return specialization_id == RAPID and not double_shot_enabled
		&"turret_rapid_extra_fifth":
			return (
				specialization_id == RAPID
				and not extra_fifth_volley_shot_enabled
			)
		&"turret_electric_chain":
			return specialization_id == ELECTRIC and not chain_enabled
	return false
