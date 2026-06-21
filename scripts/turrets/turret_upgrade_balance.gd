class_name TurretUpgradeBalance
extends Resource

@export_group("Heavy")
@export_range(1.0, 300.0, 1.0) var piercing_lane_half_height: float = 24.0
@export_range(1.0, 300.0, 1.0) var explosive_radius: float = 72.0

@export_group("Electric")
@export_range(0.1, 10.0, 0.1) var stun_min_seconds: float = 1.0
@export_range(0.1, 10.0, 0.1) var stun_max_seconds: float = 2.0
@export_range(1, 10, 1) var chain_damage: int = 1
@export_range(1.0, 500.0, 1.0) var chain_range: float = 140.0
@export_range(1.0, 300.0, 1.0) var electric_orb_radius: float = 90.0
@export_range(1, 20, 1) var electric_orb_damage: int = 4


func is_valid() -> bool:
	return (
		piercing_lane_half_height > 0.0
		and explosive_radius > 0.0
		and stun_min_seconds > 0.0
		and stun_max_seconds >= stun_min_seconds
		and chain_damage > 0
		and chain_range > 0.0
		and electric_orb_radius > 0.0
		and electric_orb_damage > 0
	)
