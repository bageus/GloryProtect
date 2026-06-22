class_name TurretUpgradeBalance
extends Resource

@export_group("Heavy")
@export_range(1, 20, 1) var heavy_explosion_damage: int = 1
@export_range(1.0, 500.0, 1.0) var heavy_explosion_radius: float = 64.0

@export_group("Electric")
@export_range(0.1, 10.0, 0.1) var stun_min_seconds: float = 1.0
@export_range(0.1, 10.0, 0.1) var stun_max_seconds: float = 2.0
@export_range(1, 20, 1) var electric_orb_damage: int = 4
@export_range(1.0, 500.0, 1.0) var electric_orb_radius: float = 96.0


func is_valid() -> bool:
	return (
		heavy_explosion_damage > 0
		and heavy_explosion_radius > 0.0
		and stun_min_seconds > 0.0
		and stun_max_seconds >= stun_min_seconds
		and electric_orb_damage > 0
		and electric_orb_radius > 0.0
	)
