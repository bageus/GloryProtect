class_name GameBalanceMaster
extends RefCounted

## Единый источник числового баланса.
## Секунды — время, px/s — скорость, 0.15 — 15%.
## Линейные бонусы суммируются от базы; специализации умножают результат;
## временная скорость атаки делит итоговый кулдаун.
## surface_speed — каноническая скорость перемещения по ровной поверхности.
## ground_speed/platform_speed сохранены только как совместимые runtime-поля и
## всегда должны быть равны surface_speed.

const VERSION := 2
const MIN_INTERVAL := 0.05
const CREW_BASE_HEALTH := 3
const CREW_SURFACE_SPEED := 180.0

const RUN := {
	"start_safe_delay": 3.0,
	"seconds_to_max_difficulty": 600.0,
	"difficulty_growth_exponent": 1.0,
}

const CREW := {
	"starting_count": 3,
	"maximum_count": 8,
	"health": CREW_BASE_HEALTH,
	"surface_speed": CREW_SURFACE_SPEED,
	"move_speed": CREW_SURFACE_SPEED, # Совместимый псевдоним.
	"replacement_delay": 12.0,
}

const PORTAL := {
	"respawn_reduction_per_level": [0.25, 0.25],
	"final_delays": [12.0, 9.0, 6.0],
}

const MELEE := {
	"base": {
		"damage": 1,
		"health": CREW_BASE_HEALTH,
		"surface_speed": CREW_SURFACE_SPEED,
		"range": 34.0,
		"windup": 0.38,
		"cooldown": 0.62,
	},
	"lines": {
		"damage_flat": [1, 1],
		"cooldown_reduction": [0.15, 0.15],
		"health_flat": [1, 1],
	},
	"individual": {"maximum_survivability_health": 1},
	"heavy": {
		"health": 1,
		"blocks_jump": true,
		"shield_armor": 2,
		"bash_every_hits": 5,
		"bash_targets": 2,
		"bash_damage": 1,
	},
	"duelist": {
		"cooldown_multiplier": 0.75,
		"isolated_damage": 1,
		"attack_sequence": 2,
		"counterattack": true,
	},
	"assault": {
		"splash_damage": 1,
		"splash_targets": 3,
		"front_attacks": 2,
		"rear_attacks": 1,
		"lethal_guard_health": 1,
		"lethal_guard_uses_per_life": 1,
	},
}

const SHOOTER := {
	"base": {
		"health": CREW_BASE_HEALTH,
		"surface_speed": CREW_SURFACE_SPEED,
		"damage": 1,
		"windup": 0.60,
		"cooldown": 1.0,
		"attack_mode": "projectile",
		"projectile_speed": 520.0,
		"range": 420.0,
	},
	"lines": {
		"damage_flat": [1, 1],
		"range_bonus": [0.20, 0.20],
		"cooldown_reduction": [0.15, 0.15],
	},
	"pierce_targets": 1,
	"sniper": {
		"damage": 1,
		"range_bonus": 0.10,
		"pierce_targets": 4,
		"explosion_every": 5,
		"explosion_radius": 72.0,
	},
	"air_hunter": {
		"air_damage": 1,
		"sequence": 3,
		"mark_every": 5,
		"mark_duration": 10.0,
		"mark_damage_multiplier": 1.50,
	},
	"anchor_hunter": {
		"anchor_damage": 1,
		"sequence": 3,
		"knockdown_every": 5,
	},
}

const MEDIC := {
	"base": {
		"health": CREW_BASE_HEALTH,
		"surface_speed": CREW_SURFACE_SPEED,
		"heal_amount": 1,
		"heal_interval": 5.0,
		"range": 18.0,
	},
	"lines": {
		"heal_flat": [1, 1],
		"heal_speed_bonus": [0.20, 0.20],
		"range_bonus": [0.15, 0.15],
	},
	"individual": {"health": 2, "armor": 2},
	"field": {
		"move_speed_bonus": 0.15,
		"damage": 1,
		"emergency_health": 1,
		"emergency_interval_multiplier": 0.50,
	},
	"stimulant": {
		"duration": 5.0,
		"attack_speed_bonus": 0.15,
		"move_speed_bonus": 0.15,
		"revival_cooldown": 60.0,
	},
	"protective": {
		"armor_per_segment": 1,
		"ignore_hit_after_full_heal": true,
		"chain_heal_ratio": 0.50,
	},
}

const TURRET := {
	"base": {
		"maximum_count": 4,
		"damage": 1,
		"range": 360.0,
		"windup": 0.45,
		"cooldown": 0.80,
		"attack_mode": "hitscan",
		"tracer_duration": 0.14,
	},
	"lines": {
		"damage_flat": [1, 1],
		"cooldown_reduction": [0.15, 0.15],
		"range_bonus": [0.20, 0.20],
	},
	"heavy": {
		"damage": 1,
		"piercing": true,
		"explosion_every": 5,
		"explosion_damage": 1,
		"explosion_radius": 64.0,
	},
	"rapid": {
		"cooldown_multiplier": 0.50,
		"double_shot": 2,
		"extra_shot_every": 5,
	},
	"electric": {
		"stun_min": 1.0,
		"stun_max": 2.0,
		"chain_targets": 1,
		"orb_every": 5,
		"orb_damage": 4,
		"orb_radius": 96.0,
	},
}

const PLATFORM := {
	"cells": 18,
	"steering_force": 178.0,
	"linear_drag": 36.0,
	"max_speed": 310.0,
	"world_min_x": -2400.0,
	"world_max_x": 2400.0,
}

const ANCHORLESS := {
	"lines": {
		"steering_bonus": [0.10, 0.10],
		"wind_reduction": [0.10, 0.10],
		"drag_bonus": [0.20, 0.20],
	},
	"ignore_wind_level": 1,
	"precise": {
		"inertia_reduction": 0.25,
		"center_half_width_ratio": 0.25,
		"center_recharge_bonus": 0.25,
	},
	"speed_flight": {
		"acceleration_bonus": 0.15,
		"max_speed_bonus": 0.15,
		"required_flight_time": 5.0,
		"minimum_speed": 40.0,
		"first_contact_restore": 0.10,
		"sweep_depth": 72.0,
	},
	"powerful": {
		"anchor_damage": 1,
		"anchor_radius": 120.0,
		"core_damage": 2,
	},
}

const WIND := {
	"forces": [42.0, 78.0, 126.0],
	"change_interval_min": 5.0,
	"change_interval_max": 9.0,
	"fluctuation_force": 8.0,
	"fluctuation_speed": 0.85,
}

const ANCHORS := {
	"base": {
		"install_time": 1.25,
		"overload_time": 2.50,
		"return_time": 0.75,
		"rope_length": 315.0,
	},
	"lines": {
		"overload_seconds": [1.0, 1.0],
		"electric_damage": 1,
		"electric_interval": 4.0,
		"advanced_electric_interval_multiplier": 0.50,
		"install_speed_bonus": [0.20, 0.20],
	},
	"strong": {
		"overload_seconds": 1.0,
		"second_anchor_speed_multiplier": 1.50,
		"enemy_fall_chance": 0.25,
	},
	"electric": {
		"pulse_damage": 1,
		"stun": 2.0,
		"stun_chance": 0.30,
		"drop_chance": 0.50,
		"pulse_radius": 130.0,
	},
	"trap": {
		"remove_damage": 1,
		"remove_radius": 145.0,
		"knockback": 90.0,
		"attach_damage": 1,
		"attach_radius": 145.0,
	},
}

const SHIELD := {
	"base": {
		"sections": 5,
		"max_percent": 100.0,
		"recharge_per_second": 8.0,
		"indicator_threshold": 50.0,
		"critical_threshold": 25.0,
		"contact_half_width": 72.0,
		"orb_positions": [-2000.0, -1000.0, 0.0, 1000.0, 2000.0],
	},
	"lines": {
		"capacity_bonus": [0.10, 0.10],
		"recharge_bonus": [0.10, 0.10],
		"contact_width_bonus": [0.10, 0.10],
	},
	"focused": {"recharge_bonus": 0.15, "retarget_ratio": 0.30},
	"distributed": {
		"transfer_ratio": 0.15,
		"emergency_floor": 1.0,
		"emergency_hold": 5.0,
		"uses_per_run": 1,
	},
	"surges": {
		"destroyed_rows_min": 1,
		"destroyed_rows_max": 2,
		"completion_restore": 15.0,
	},
}

const BOARDING := {
	"spawn_interval": 3.0,
	"minimum_spawn_interval": 0.80,
	"ground_limit": 8,
	"maximum_ground_limit": 20,
	"spawn_distance": 720.0,
	"jump_time": 0.45,
	"jump_height": 44.0,
	"jump_distance": 120.0,
}

const ENEMIES := {
	"basic": {
		"health": 1,
		"surface_speed": 125.0,
		"ground_speed": 125.0,
		"platform_speed": 125.0,
		"climb_speed": 105.0,
		"damage": 1,
		"windup": 0.55,
		"cooldown": 0.85,
		"range": 30.0,
		"unlock": 0.0,
	},
	"runner": {
		"health": 1,
		"surface_speed": 175.0,
		"ground_speed": 175.0,
		"platform_speed": 175.0,
		"climb_speed": 150.0,
		"damage": 1,
		"windup": 0.35,
		"cooldown": 0.65,
		"range": 26.0,
		"unlock": 0.15,
	},
	"brute": {
		"health": 3,
		"surface_speed": 85.0,
		"ground_speed": 85.0,
		"platform_speed": 85.0,
		"climb_speed": 70.0,
		"damage": 1,
		"windup": 0.80,
		"cooldown": 1.10,
		"range": 34.0,
		"unlock": 0.45,
	},
	"rope_saboteur": {
		"health": 1,
		"surface_speed": 155.0,
		"ground_speed": 155.0,
		"platform_speed": 155.0,
		"climb_speed": 20.0,
		"damage": 1,
		"windup": 0.50,
		"cooldown": 1.0,
		"range": 20.0,
		"rope_damage": 35.0,
		"arming_time": 1.60,
		"unlock": 0.25,
	},
	"flyer": {
		"health": 2,
		"flight_speed": 135.0,
		"spawn_interval": 14.0,
		"damage": 1,
		"windup": 0.65,
		"cooldown": 1.0,
		"range": 34.0,
	},
}

const STRATEGIC := {
	"first_wave_delay": 5.0,
	"wave_interval": 12.0,
	"minimum_wave_interval": 4.0,
	"wave_size": 6,
	"maximum_wave_size": 30,
	"travel_time": 8.0,
	"minimum_travel_time": 4.0,
	"target_sections": 1,
	"maximum_target_sections": 3,
	"impact_interval": 0.35,
	"damage_per_enemy": 1.0,
	"maximum_groups": 15,
	"split_chance": 0.04,
	"maximum_split_chance": 0.22,
}

const ECONOMY := {
	"starting_coins": 0,
	"enemy_reward": 1,
	"cards_per_offer": 3,
	"specialization_cards_required": 2,
	"linear_purchase_count": 20,
	"linear_cost_step": 5,
	"post_linear_multiplier": 2,
	"branch_weight": 10,
	"common_weight": 10,
	"chosen_branch_bonus": 3,
	"linked_branch_bonus": 1,
	"opposite_branch_penalty": 1,
	"minimum_branch_weight": 2,
}

const COMMON_UPGRADES := {
	"additional_defender": {"count": 1, "purchases": 5, "maximum_crew": 8},
	"crew_move_speed_bonus": [0.15, 0.15],
	"portal_respawn_reduction": [0.25, 0.25],
}


static func sum_levels(values: Array, levels: int) -> float:
	var result := 0.0
	for index in range(clampi(levels, 0, values.size())):
		result += float(values[index])
	return result


static func add_ratio(base_value: float, ratio: float) -> float:
	return base_value * (1.0 + maxf(0.0, ratio))


static func reduce_ratio(base_value: float, ratio: float) -> float:
	return base_value * maxf(0.0, 1.0 - clampf(ratio, 0.0, 1.0))


static func attack_cooldown(
	base_value: float,
	line_reduction: float = 0.0,
	specialization_multiplier: float = 1.0,
	temporary_speed_multiplier: float = 1.0
) -> float:
	var result := reduce_ratio(base_value, line_reduction)
	result *= maxf(0.01, specialization_multiplier)
	result /= maxf(0.01, temporary_speed_multiplier)
	return maxf(MIN_INTERVAL, result)


static func action_rate(cooldown: float) -> float:
	return 1.0 / maxf(MIN_INTERVAL, cooldown)


static func heal_interval(
	base_value: float,
	speed_bonus: float,
	emergency_multiplier: float = 1.0
) -> float:
	return maxf(
		MIN_INTERVAL,
		base_value / (1.0 + maxf(0.0, speed_bonus))
		* maxf(0.01, emergency_multiplier)
	)


static func install_time(
	base_value: float,
	speed_bonus: float,
	extra_speed_multiplier: float = 1.0
) -> float:
	return maxf(
		MIN_INTERVAL,
		base_value / (
			(1.0 + maxf(0.0, speed_bonus))
			* maxf(0.01, extra_speed_multiplier)
		)
	)


static func portal_delay(level: int) -> float:
	var reduction := sum_levels(
		COMMON_UPGRADES["portal_respawn_reduction"],
		level
	)
	return reduce_ratio(CREW["replacement_delay"], reduction)


static func upgrade_cost(completed_purchases: int) -> int:
	var count := maxi(0, completed_purchases)
	var linear_count: int = ECONOMY["linear_purchase_count"]
	var step: int = ECONOMY["linear_cost_step"]
	if count < linear_count:
		return (count + 1) * step
	var cost := linear_count * step
	for _index in range(count - linear_count + 1):
		cost *= int(ECONOMY["post_linear_multiplier"])
	return cost


static func reference_finals() -> Dictionary:
	var melee_speed := sum_levels(MELEE["lines"]["cooldown_reduction"], 2)
	var shooter_speed := sum_levels(SHOOTER["lines"]["cooldown_reduction"], 2)
	var turret_speed := sum_levels(TURRET["lines"]["cooldown_reduction"], 2)
	var heal_speed := sum_levels(MEDIC["lines"]["heal_speed_bonus"], 2)
	var anchor_speed := sum_levels(ANCHORS["lines"]["install_speed_bonus"], 2)
	return {
		"portal_delays": [portal_delay(0), portal_delay(1), portal_delay(2)],
		"melee_cooldowns": [
			MELEE["base"]["cooldown"],
			attack_cooldown(MELEE["base"]["cooldown"], 0.15),
			attack_cooldown(MELEE["base"]["cooldown"], melee_speed),
			attack_cooldown(
				MELEE["base"]["cooldown"],
				melee_speed,
				MELEE["duelist"]["cooldown_multiplier"]
			),
		],
		"shooter_cooldowns": [
			SHOOTER["base"]["cooldown"],
			attack_cooldown(SHOOTER["base"]["cooldown"], shooter_speed),
		],
		"turret_cooldowns": [
			TURRET["base"]["cooldown"],
			attack_cooldown(TURRET["base"]["cooldown"], turret_speed),
			attack_cooldown(
				TURRET["base"]["cooldown"],
				turret_speed,
				TURRET["rapid"]["cooldown_multiplier"]
			),
		],
		"heal_intervals": [
			MEDIC["base"]["heal_interval"],
			heal_interval(MEDIC["base"]["heal_interval"], heal_speed),
			heal_interval(
				MEDIC["base"]["heal_interval"],
				heal_speed,
				MEDIC["field"]["emergency_interval_multiplier"]
			),
		],
		"anchor_install_times": [
			ANCHORS["base"]["install_time"],
			install_time(ANCHORS["base"]["install_time"], anchor_speed),
			install_time(
				ANCHORS["base"]["install_time"],
				anchor_speed,
				ANCHORS["strong"]["second_anchor_speed_multiplier"]
			),
		],
		"shield_recharge": [
			SHIELD["base"]["recharge_per_second"],
			add_ratio(SHIELD["base"]["recharge_per_second"], 0.20),
			add_ratio(
				SHIELD["base"]["recharge_per_second"],
				0.20 + SHIELD["focused"]["recharge_bonus"]
			),
		],
		"upgrade_costs": [
			upgrade_cost(0), upgrade_cost(19), upgrade_cost(20),
			upgrade_cost(21), upgrade_cost(22),
		],
	}
