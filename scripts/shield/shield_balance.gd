class_name ShieldBalance
extends Resource

@export_range(1, 12, 1) var section_count: int = 5
@export_range(1.0, 1000.0, 1.0) var max_health: float = 100.0
@export_range(0.0, 100.0, 0.1) var recharge_per_second: float = 8.0
@export_range(0.0, 100.0, 0.1) var indicator_threshold_percent: float = 50.0
@export_range(0.0, 100.0, 0.1) var critical_threshold_percent: float = 25.0
@export_range(0.0, 100.0, 1.0) var debug_damage_amount: float = 10.0
@export var section_colors := PackedColorArray([
	Color(0.3, 0.85, 1.0),
	Color(0.45, 0.95, 0.5),
	Color(1.0, 0.82, 0.28),
	Color(1.0, 0.48, 0.25),
	Color(0.88, 0.38, 1.0),
])
