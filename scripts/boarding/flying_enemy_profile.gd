class_name FlyingEnemyProfile
extends Resource

@export var archetype: BoardingEnemyArchetype
@export_range(1.0, 1000.0, 1.0) var flight_speed: float = 120.0
@export_range(0.0, 500.0, 1.0) var hover_height: float = 90.0
@export_range(1.0, 1000.0, 1.0) var spawn_distance: float = 720.0
@export_range(0.1, 120.0, 0.1) var spawn_interval: float = 6.0
@export_range(0.1, 120.0, 0.1) var minimum_spawn_interval: float = 2.7
@export_range(0.5, 1.0, 0.01) var overtime_spawn_interval_multiplier: float = 0.95
@export_range(0.1, 120.0, 0.1) var minimum_overtime_spawn_interval: float = 2.0
@export_range(1.0, 500.0, 1.0) var attack_range: float = 34.0
@export_range(1.0, 500.0, 1.0) var separation_distance: float = 44.0
@export_range(0.0, 500.0, 1.0) var separation_force: float = 90.0


func get_spawn_interval(
	normalized_difficulty: float,
	overtime_tier: int = 0
) -> float:
	var progress: float = clampf(normalized_difficulty, 0.0, 1.0)
	var final_interval: float = minf(spawn_interval, minimum_spawn_interval)
	var result: float = lerpf(spawn_interval, final_interval, progress)
	if overtime_tier > 0:
		result *= pow(overtime_spawn_interval_multiplier, overtime_tier)
	return maxf(minimum_overtime_spawn_interval, result)


func is_valid() -> bool:
	return (
		archetype != null
		and archetype.is_valid()
		and flight_speed > 0.0
		and spawn_distance > 0.0
		and spawn_interval > 0.0
		and minimum_spawn_interval > 0.0
		and minimum_overtime_spawn_interval > 0.0
		and attack_range > 0.0
		and separation_distance > 0.0
	)
