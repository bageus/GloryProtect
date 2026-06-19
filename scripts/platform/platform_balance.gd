class_name PlatformBalance
extends Resource

@export_range(8, 32, 1) var cell_count: int = 18
@export_range(16.0, 64.0, 1.0) var cell_width: float = 40.0
@export_range(24.0, 100.0, 1.0) var platform_height: float = 58.0
@export_range(0.0, 500.0, 1.0) var steering_force: float = 178.0
@export_range(0.0, 300.0, 1.0) var linear_drag: float = 36.0
@export_range(20.0, 1000.0, 1.0) var max_horizontal_speed: float = 310.0
@export var world_min_x: float = -2400.0
@export var world_max_x: float = 2400.0

@export_range(0.0, 200.0, 1.0) var driver_post_width: float = 36.0
@export_range(0.0, 200.0, 1.0) var driver_post_height: float = 72.0
@export_range(0.0, 200.0, 1.0) var anchor_post_width: float = 28.0
@export_range(0.0, 200.0, 1.0) var anchor_post_height: float = 58.0
@export_range(0.0, 10.0, 0.1) var anchor_post_cell_inset: float = 1.5
