class_name TurretUpgradeBalance
extends Resource

@export_group("Electric")
@export_range(0.1, 10.0, 0.1) var stun_min_seconds: float = 1.0
@export_range(0.1, 10.0, 0.1) var stun_max_seconds: float = 2.0


func is_valid() -> bool:
	return (
		stun_min_seconds > 0.0
		and stun_max_seconds >= stun_min_seconds
	)
