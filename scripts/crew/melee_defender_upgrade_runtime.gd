class_name MeleeDefenderUpgradeRuntime
extends RefCounted

const HEAVY: StringName = &"heavy"
const DUELIST: StringName = &"duelist"
const ASSAULT: StringName = &"assault"

var damage_bonus: int = 0
var cooldown_multiplier: float = 1.0
var health_bonus: int = 0
var armor_bonus: int = 0
var specialization_id: StringName = &""
var heavy_blocks_jump: bool = false
var heavy_shield_bash: bool = false
var duelist_isolated_damage: bool = false
var duelist_double_attack: bool = false
var duelist_counterattack: bool = false
var assault_splash: bool = false
var assault_back_attack: bool = false
var assault_lethal_guard: bool = false


func reset() -> void:
	damage_bonus = 0
	cooldown_multiplier = 1.0
	health_bonus = 0
	armor_bonus = 0
	specialization_id = &""
	heavy_blocks_jump = false
	heavy_shield_bash = false
	duelist_isolated_damage = false
	duelist_double_attack = false
	duelist_counterattack = false
	assault_splash = false
	assault_back_attack = false
	assault_lethal_guard = false


func apply_scalar(target_id: StringName, value: float) -> bool:
	match target_id:
		&"melee_damage_bonus":
			damage_bonus += roundi(value)
			return true
		&"melee_cooldown_multiplier":
			if value <= 0.0 or value > 1.0:
				return false
			_apply_cooldown_reduction(1.0 - value)
			return true
		&"melee_health_bonus":
			health_bonus += roundi(value)
			return true
		&"melee_armor_bonus":
			armor_bonus += roundi(value)
			return true
	return false


func apply_flag(target_id: StringName) -> bool:
	match target_id:
		&"melee_specialization_heavy":
			specialization_id = HEAVY
			health_bonus += 1
			heavy_blocks_jump = true
			return true
		&"melee_heavy_shield":
			armor_bonus += 2
			return true
		&"melee_heavy_shield_bash":
			heavy_shield_bash = true
			return true
		&"melee_specialization_duelist":
			specialization_id = DUELIST
			_apply_cooldown_reduction(0.25)
			return true
		&"melee_duelist_isolated_damage":
			duelist_isolated_damage = true
			return true
		&"melee_duelist_double_attack":
			duelist_double_attack = true
			return true
		&"melee_duelist_counterattack":
			duelist_counterattack = true
			return true
		&"melee_specialization_assault":
			specialization_id = ASSAULT
			assault_splash = true
			return true
		&"melee_assault_back_attack":
			assault_back_attack = true
			return true
		&"melee_assault_lethal_guard":
			assault_lethal_guard = true
			return true
	return false


func get_damage(base_damage: int) -> int:
	return maxi(1, base_damage + damage_bonus)


func get_cooldown(base_cooldown: float) -> float:
	return maxf(0.01, base_cooldown * cooldown_multiplier)


func get_max_health(base_health: int) -> int:
	return maxi(1, base_health + health_bonus)


func _apply_cooldown_reduction(reduction: float) -> void:
	cooldown_multiplier = maxf(0.01, cooldown_multiplier - maxf(0.0, reduction))
