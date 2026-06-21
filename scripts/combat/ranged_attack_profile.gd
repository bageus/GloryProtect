class_name RangedAttackProfile
extends Resource

@export_range(1, 100, 1) var damage: int = 1
@export_range(0.01, 10.0, 0.01) var windup_duration: float = 0.6
@export_range(0.01, 10.0, 0.01) var cooldown_duration: float = 1.0
@export_range(1.0, 2000.0, 1.0) var projectile_speed: float = 420.0
@export_range(1.0, 2000.0, 1.0) var maximum_range: float = 360.0


func is_valid() -> bool:
	return (
		damage > 0
		and windup_duration > 0.0
		and cooldown_duration > 0.0
		and projectile_speed > 0.0
		and maximum_range > 0.0
	)
