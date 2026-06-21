class_name RopeSaboteurArchetype
extends BoardingEnemyArchetype

@export_group("Rope Sabotage")
@export_range(1.0, 1000.0, 1.0) var rope_damage: float = 35.0
@export_range(0.1, 10.0, 0.1) var arming_duration: float = 1.6


func is_valid() -> bool:
	return (
		super()
		and enemy_scene != null
		and rope_damage > 0.0
		and arming_duration > 0.0
	)
