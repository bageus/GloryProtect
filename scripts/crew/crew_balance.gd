class_name CrewBalance
extends Resource

@export_range(1, 12, 1) var starting_defender_count: int = 3
@export_range(1, 10, 1) var defender_max_health: int = 3
@export_range(20.0, 600.0, 1.0) var defender_move_speed: float = 180.0
@export_range(-200.0, 100.0, 1.0) var defender_local_y: float = -48.0
@export_range(4.0, 40.0, 1.0) var defender_body_radius: float = 14.0
@export_range(0.0, 5.0, 0.1) var anchor_station_cell_inset: float = 1.5
