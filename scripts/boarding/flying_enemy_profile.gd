class_name FlyingEnemyProfile
extends Resource

@export var archetype: BoardingEnemyArchetype
@export_range(1.0, 1000.0, 1.0) var flight_speed: float = 120.0
@export_range(0.0, 500.0, 1.0) var hover_height: float = 90.0
@export_range(1.0, 1000.0, 1.0) var spawn_distance: float = 720.0
@export_range(0.1, 120.0, 0.1) var spawn_interval: float = 12.0
@export_range(1.0, 500.0, 1.0) var attack_range: float = 34.0
@export_range(1.0, 500.0, 1.0) var separation_distance: float = 44.0
@export_range(0.0, 500.0, 1.0) var separation_force: float = 90.0


func is_valid() -> bool:
	return (
		archetype != null
		and archetype.is_valid()
		and flight_speed > 0.0
		and spawn_distance > 0.0
		and spawn_interval > 0.0
		and attack_range > 0.0
		and separation_distance > 0.0
	)
