class_name ShooterSpecializationBalance
extends Resource

@export_range(1.0, 300.0, 1.0) var piercing_lane_half_height: float = 24.0
@export_range(1, 10, 1) var base_pierce_target_count: int = 1
@export_range(1, 10, 1) var sniper_pierce_target_count: int = 4
@export_range(1.0, 300.0, 1.0) var explosive_radius: float = 72.0
@export_range(0.1, 60.0, 0.1) var mark_duration: float = 10.0
@export_range(1.0, 5.0, 0.1) var mark_damage_multiplier: float = 1.5


func is_valid() -> bool:
	return (
		piercing_lane_half_height > 0.0
		and base_pierce_target_count > 0
		and sniper_pierce_target_count >= base_pierce_target_count
		and explosive_radius > 0.0
		and mark_duration > 0.0
		and mark_damage_multiplier > 1.0
	)
