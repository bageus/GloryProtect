class_name AnchorlessControlBalance
extends Resource

@export_group("Precise Stabilization")
@export_range(0.0, 1.0, 0.05) var precise_inertia_reduction_ratio: float = 0.25
@export_range(0.05, 1.0, 0.05) var precise_center_half_width_ratio: float = 0.25
@export_range(0.0, 2.0, 0.05) var precise_recharge_bonus_ratio: float = 0.25

@export_group("Speed Flight")
@export_range(0.0, 2.0, 0.05) var speed_acceleration_bonus_ratio: float = 0.15
@export_range(0.0, 2.0, 0.05) var speed_max_speed_bonus_ratio: float = 0.15
@export_range(0.1, 60.0, 0.1) var long_flight_required_seconds: float = 5.0
@export_range(0.0, 1000.0, 1.0) var long_flight_minimum_speed: float = 40.0
@export_range(0.0, 1.0, 0.01) var long_flight_restore_ratio: float = 0.10
@export_range(1.0, 500.0, 1.0) var front_sweep_depth: float = 72.0
@export_range(1.0, 500.0, 1.0) var front_sweep_vertical_radius: float = 260.0

@export_group("Powerful Stabilization")
@export_range(1, 10, 1) var anchor_discharge_damage: int = 1
@export_range(1.0, 500.0, 1.0) var anchor_discharge_radius: float = 120.0
@export_range(1, 10, 1) var core_pulse_damage: int = 2


func is_valid() -> bool:
	return (
		precise_inertia_reduction_ratio >= 0.0
		and precise_center_half_width_ratio > 0.0
		and precise_center_half_width_ratio <= 1.0
		and precise_recharge_bonus_ratio >= 0.0
		and speed_acceleration_bonus_ratio >= 0.0
		and speed_max_speed_bonus_ratio >= 0.0
		and long_flight_required_seconds > 0.0
		and long_flight_minimum_speed >= 0.0
		and long_flight_restore_ratio > 0.0
		and long_flight_restore_ratio <= 1.0
		and front_sweep_depth > 0.0
		and front_sweep_vertical_radius > 0.0
		and anchor_discharge_damage > 0
		and anchor_discharge_radius > 0.0
		and core_pulse_damage > 0
	)
