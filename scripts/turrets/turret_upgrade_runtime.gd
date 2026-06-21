class_name TurretUpgradeRuntime
extends RefCounted

const HEAVY: StringName = &"heavy"
const RAPID: StringName = &"rapid"
const ELECTRIC: StringName = &"electric"

var damage_bonus: int = 0
var cooldown_multiplier: float = 1.0
var range_multiplier: float = 1.0
var specialization_id: StringName = &""
var piercing_enabled: bool = false
var explosive_fifth_enabled: bool = false
var double_shot_enabled: bool = false
var extra_fifth_shot_enabled: bool = false
var stun_enabled: bool = false
var chain_enabled: bool = false
var electric_orb_enabled: bool = false


func reset() -> void:
	damage_bonus = 0
	cooldown_multiplier = 1.0
	range_multiplier = 1.0
	specialization_id = &""
	piercing_enabled = false
	explosive_fifth_enabled = false
	double_shot_enabled = false
	extra_fifth_shot_enabled = false
	stun_enabled = false
	chain_enabled = false
	electric_orb_enabled = false


func apply_scalar(target_id: StringName, value: float) -> bool:
	match target_id:
		&"turret_damage_bonus":
			damage_bonus += roundi(value)
			return true
		&"turret_cooldown_multiplier":
			if value <= 0.0:
				return false
			cooldown_multiplier *= value
			return true
		&"turret_range_multiplier":
			if value <= 0.0:
				return false
			range_multiplier *= value
			return true
	return false


func apply_flag(target_id: StringName) -> bool:
	match target_id:
		&"turret_specialization_heavy":
			specialization_id = HEAVY
			damage_bonus += 1
			return true
		&"turret_heavy_piercing":
			piercing_enabled = true
			return true
		&"turret_heavy_explosive_fifth":
			explosive_fifth_enabled = true
			return true
		&"turret_specialization_rapid":
			specialization_id = RAPID
			cooldown_multiplier *= 0.5
			return true
		&"turret_rapid_double_shot":
			double_shot_enabled = true
			return true
		&"turret_rapid_extra_fifth":
			extra_fifth_shot_enabled = true
			return true
		&"turret_specialization_electric":
			specialization_id = ELECTRIC
			stun_enabled = true
			return true
		&"turret_electric_chain":
			chain_enabled = true
			return true
		&"turret_electric_orb_fifth":
			electric_orb_enabled = true
			return true
	return false


func get_damage(base_damage: int) -> int:
	return maxi(1, base_damage + damage_bonus)


func get_cooldown(base_cooldown: float) -> float:
	return maxf(0.0, base_cooldown * cooldown_multiplier)


func get_range(base_range: float) -> float:
	return maxf(0.0, base_range * range_multiplier)
