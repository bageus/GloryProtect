class_name AnchorBalance
extends Resource

@export_range(40.0, 400.0, 1.0) var installation_zone_half_width: float = 145.0
@export_range(0.1, 10.0, 0.1) var install_duration: float = 1.25
@export_range(0.1, 10.0, 0.1) var overload_duration: float = 2.5
@export_range(0.1, 5.0, 0.1) var return_duration: float = 0.75
@export_range(100.0, 1000.0, 1.0) var rope_length: float = 315.0
@export_range(1.0, 1000.0, 1.0) var rope_max_durability: float = 100.0
@export_range(0.0, 200.0, 1.0) var overload_stretch: float = 42.0
@export_range(0.1, 20.0, 0.1) var tension_epsilon: float = 2.0
@export var ground_offsets := PackedFloat32Array([-230.0, -125.0, 125.0, 230.0])
@export_range(0.0, 200.0, 1.0) var platform_outer_inset: float = 22.0
@export_range(0.0, 200.0, 1.0) var platform_inner_inset: float = 74.0
@export_range(0.0, 1.0, 0.01) var platform_attachment_y_factor: float = 0.45
