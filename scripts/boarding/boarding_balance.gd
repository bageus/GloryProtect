class_name BoardingBalance
extends Resource

@export var enemy_catalog: BoardingEnemyCatalog

@export_group("Legacy Base Enemy Defaults")
@export_range(1, 20, 1) var enemy_max_health: int = 1
@export_range(20.0, 500.0, 1.0) var ground_move_speed: float = 125.0
@export_range(20.0, 500.0, 1.0) var climb_move_speed: float = 105.0
@export_range(20.0, 500.0, 1.0) var platform_move_speed: float = 125.0
@export_range(4.0, 40.0, 1.0) var enemy_body_radius: float = 12.0

@export_group("Spawn")
@export_range(0.0, 100.0, 1.0) var ground_vertical_offset: float = 12.0
@export_range(-100.0, 100.0, 1.0) var platform_local_y: float = -48.0
@export_range(0.0, 100.0, 1.0) var ground_arrival_epsilon: float = 8.0
@export_range(10.0, 1000.0, 1.0) var spawn_distance_from_platform: float = 720.0
@export_range(0.1, 30.0, 0.1) var spawn_interval: float = 3.0
@export_range(0.1, 30.0, 0.1) var minimum_spawn_interval: float = 0.8
@export_range(1, 100, 1) var max_ground_enemies: int = 8
@export_range(1, 200, 1) var maximum_ground_enemies: int = 28
@export_range(0.0, 200.0, 1.0) var path_tie_epsilon: float = 24.0

@export_group("Overtime Spawn")
@export_range(0, 20, 1) var overtime_ground_limit_per_tier: int = 2
@export_range(1, 200, 1) var maximum_overtime_ground_enemies: int = 36
@export_range(0.5, 1.0, 0.01) var overtime_spawn_interval_multiplier: float = 0.95
@export_range(0.1, 5.0, 0.05) var minimum_overtime_spawn_interval: float = 0.55

@export_group("Separation")
@export_range(4.0, 120.0, 1.0) var ground_enemy_spacing: float = 28.0
@export_range(4.0, 120.0, 1.0) var climb_enemy_spacing: float = 30.0
@export_range(4.0, 120.0, 1.0) var platform_enemy_spacing: float = 28.0

@export_group("Enemy Jump")
@export_range(0.1, 2.0, 0.05) var jump_duration: float = 0.45
@export_range(4.0, 160.0, 1.0) var jump_height: float = 44.0
@export_range(0.0, 40.0, 1.0) var jump_landing_clearance: float = 2.0
@export_range(0.0, 40.0, 1.0) var jump_trigger_tolerance: float = 4.0
@export_range(20.0, 240.0, 1.0) var jump_max_horizontal_distance: float = 120.0

@export_group("Legacy Base Enemy Combat")
@export_range(1, 20, 1) var enemy_attack_damage: int = 1
@export_range(0.05, 5.0, 0.05) var enemy_attack_windup: float = 0.55
@export_range(0.05, 5.0, 0.05) var enemy_attack_cooldown: float = 0.85
@export_range(5.0, 200.0, 1.0) var enemy_attack_range: float = 30.0

@export_group("Defender Combat")
@export_range(1, 20, 1) var defender_attack_damage: int = 1
@export_range(0.05, 5.0, 0.05) var defender_attack_windup: float = 0.45
@export_range(0.05, 5.0, 0.05) var defender_attack_cooldown: float = 0.55
@export_range(5.0, 200.0, 1.0) var defender_attack_range: float = 34.0
@export_range(10.0, 500.0, 1.0) var post_combat_radius: float = 150.0


func get_spawn_interval_for_difficulty(
	normalized_difficulty: float,
	overtime_tier: int = 0
) -> float:
	var progress: float = clampf(normalized_difficulty, 0.0, 1.0)
	var final_interval: float = minf(spawn_interval, minimum_spawn_interval)
	var result: float = lerpf(spawn_interval, final_interval, progress)
	if overtime_tier > 0:
		result *= pow(overtime_spawn_interval_multiplier, overtime_tier)
	return maxf(minimum_overtime_spawn_interval, result)


func get_ground_limit_for_difficulty(
	normalized_difficulty: float,
	overtime_tier: int = 0
) -> int:
	var progress: float = clampf(normalized_difficulty, 0.0, 1.0)
	var final_limit: int = maxi(max_ground_enemies, maximum_ground_enemies)
	var result: int = roundi(lerpf(float(max_ground_enemies), float(final_limit), progress))
	result += maxi(0, overtime_tier) * overtime_ground_limit_per_tier
	return mini(maximum_overtime_ground_enemies, result)
