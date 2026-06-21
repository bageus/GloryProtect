class_name PoisonEffectProfile
extends Resource

@export_range(1, 100, 1) var damage_per_tick: int = 1
@export_range(0.1, 60.0, 0.1) var tick_interval: float = 2.0
@export_range(0.1, 300.0, 0.1) var duration: float = 8.0
@export_range(1, 20, 1) var maximum_stacks: int = 1


func is_valid() -> bool:
	return (
		damage_per_tick > 0
		and tick_interval > 0.0
		and duration > 0.0
		and maximum_stacks > 0
	)
