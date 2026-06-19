class_name WindBalance
extends Resource

@export var level_forces := PackedFloat32Array([42.0, 78.0, 126.0])
@export_range(1.0, 30.0, 0.1) var change_interval_min: float = 5.0
@export_range(1.0, 30.0, 0.1) var change_interval_max: float = 9.0
@export_range(0.0, 50.0, 0.1) var fluctuation_force: float = 8.0
@export_range(0.1, 5.0, 0.1) var fluctuation_speed: float = 0.85
