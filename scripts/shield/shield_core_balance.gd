class_name ShieldCoreBalance
extends Resource

@export_range(0.0, 1.0, 0.01) var focused_recharge_bonus_ratio: float = 0.15
@export_range(0.0, 1.0, 0.01) var focused_retarget_ratio: float = 0.30
@export_range(0.0, 1.0, 0.01) var distributed_transfer_ratio: float = 0.15
@export_range(0.1, 100.0, 0.1) var emergency_floor_percent: float = 1.0
@export_range(0.0, 30.0, 0.1) var emergency_hold_seconds: float = 5.0
@export_range(1, 10, 1) var surge_min_rows: int = 1
@export_range(1, 10, 1) var surge_max_rows: int = 2
@export_range(0.0, 100.0, 0.1) var surge_completion_restore_percent: float = 15.0


func is_valid() -> bool:
	return (
		focused_recharge_bonus_ratio >= 0.0
		and focused_retarget_ratio >= 0.0
		and focused_retarget_ratio <= 1.0
		and distributed_transfer_ratio >= 0.0
		and distributed_transfer_ratio <= 1.0
		and emergency_floor_percent > 0.0
		and emergency_floor_percent <= 100.0
		and emergency_hold_seconds >= 0.0
		and surge_min_rows > 0
		and surge_max_rows >= surge_min_rows
		and surge_completion_restore_percent >= 0.0
		and surge_completion_restore_percent <= 100.0
	)


func get_surge_row_count(rng: RandomNumberGenerator) -> int:
	if rng == null or surge_min_rows == surge_max_rows:
		return surge_min_rows
	return rng.randi_range(surge_min_rows, surge_max_rows)
