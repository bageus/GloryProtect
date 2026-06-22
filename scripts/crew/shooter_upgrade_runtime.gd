class_name ShooterUpgradeRuntime
extends RefCounted

const SNIPER: StringName = &"sniper"
const AIR_HUNTER: StringName = &"air_hunter"
const ANCHOR_HUNTER: StringName = &"anchor_hunter"

var role_unlocked := false
var damage_bonus := 0
var range_multiplier := 1.0
var cooldown_multiplier := 1.0
var specialization_id: StringName = &""
var piercing_enabled := false
var sniper_multi_pierce := false
var sniper_explosive_fifth := false
var air_triple_shot := false
var air_mark_fifth := false
var anchor_triple_shot := false
var anchor_knockdown_fifth := false

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

func apply_scalar(target_id: StringName, value: float) -> bool:
	match target_id:
		&"shooter_damage_bonus": damage_bonus += roundi(value)
		&"shooter_range_multiplier":
			if value <= 0.0: return false
			range_multiplier *= value
		&"shooter_cooldown_multiplier":
			if value <= 0.0: return false
			cooldown_multiplier *= value
		_: return false
	return true

func apply_flag(target_id: StringName) -> bool:
	match target_id:
		&"shooter_role_unlocked":
			if role_unlocked: return false
			role_unlocked = true
		&"shooter_piercing_bolt":
			if piercing_enabled: return false
			piercing_enabled = true
		&"shooter_specialization_sniper":
			if specialization_id != &"": return false
			specialization_id = SNIPER
			damage_bonus += 1
			range_multiplier *= 1.1
		&"shooter_sniper_multi_pierce":
			if specialization_id != SNIPER or sniper_multi_pierce: return false
			sniper_multi_pierce = true
		&"shooter_sniper_explosive_fifth":
			if specialization_id != SNIPER or sniper_explosive_fifth: return false
			sniper_explosive_fifth = true
		&"shooter_specialization_air_hunter":
			if specialization_id != &"": return false
			specialization_id = AIR_HUNTER
		&"shooter_air_triple_shot":
			if specialization_id != AIR_HUNTER or air_triple_shot: return false
			air_triple_shot = true
		&"shooter_air_mark_fifth":
			if specialization_id != AIR_HUNTER or air_mark_fifth: return false
			air_mark_fifth = true
		&"shooter_specialization_anchor_hunter":
			if specialization_id != &"": return false
			specialization_id = ANCHOR_HUNTER
		&"shooter_anchor_triple_shot":
			if specialization_id != ANCHOR_HUNTER or anchor_triple_shot: return false
			anchor_triple_shot = true
		&"shooter_anchor_knockdown_fifth":
			if specialization_id != ANCHOR_HUNTER or anchor_knockdown_fifth: return false
			anchor_knockdown_fifth = true
		_: return false
	return true

func get_damage(base_damage: int, target_domain: int, target_is_climbing := false) -> int:
	var result := maxi(1, base_damage + damage_bonus)
	if specialization_id == AIR_HUNTER and target_domain == EnemyBehaviorComponent.TargetDomain.AIR:
		result += 1
	if specialization_id == ANCHOR_HUNTER and target_is_climbing:
		result += 1
	return result

func get_range(base_range: float) -> float:
	return maxf(1.0, base_range * range_multiplier)

func get_cooldown(base_cooldown: float) -> float:
	return maxf(0.01, base_cooldown * cooldown_multiplier)
