class_name GroundOrbCatalog
extends Resource

@export var world_positions := PackedFloat32Array([
	-2000.0,
	-1000.0,
	0.0,
	1000.0,
	2000.0,
])
@export var ground_y: float = 510.0
@export_range(10.0, 300.0, 1.0) var contact_half_width: float = 72.0
@export_range(0.0, 200.0, 1.0) var orb_vertical_offset: float = 20.0
@export_range(4.0, 100.0, 1.0) var orb_core_radius: float = 25.0
@export_range(4.0, 120.0, 1.0) var orb_outer_radius: float = 43.0
@export_range(0.0, 1000.0, 1.0) var ground_depth: float = 260.0


func get_orb_count() -> int:
	return world_positions.size()
