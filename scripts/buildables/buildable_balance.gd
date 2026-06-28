class_name BuildableBalance
extends Resource

const DEFAULT_MEDICAL_CELL: int = 6
const DEFAULT_BUILDABLE_CELLS: Array[int] = [2, 3, 4, 5, 6, 7, 12, 13, 14, 15]
const DEFAULT_RESERVED_CELLS: Array[int] = [0, 1, 8, 9, 10, 11, 16, 17]

@export_group("Inventory")
@export_range(0, 8, 1) var medical_station_max_count: int = 1
@export_range(0, 16, 1) var turret_max_count: int = 4
@export_range(0, 32, 1) var default_medical_cell: int = DEFAULT_MEDICAL_CELL
@export var medical_station_cell_indices: Array[int] = DEFAULT_BUILDABLE_CELLS.duplicate()
@export var turret_cell_indices: Array[int] = DEFAULT_BUILDABLE_CELLS.duplicate()
@export var reserved_cell_indices: Array[int] = DEFAULT_RESERVED_CELLS.duplicate()

@export_group("Medical Station")
@export_range(0.1, 30.0, 0.1) var heal_interval: float = 5.0
@export_range(1, 10, 1) var heal_amount: int = 1
@export_range(1.0, 120.0, 1.0) var heal_range: float = 18.0
@export_range(10.0, 180.0, 1.0) var medical_station_width: float = 34.0
@export_range(20.0, 160.0, 1.0) var medical_station_height: float = 50.0
@export_range(-120.0, 20.0, 1.0) var medical_station_bottom_y: float = -28.0

@export_group("Turret Combat")
@export_range(1, 10, 1) var turret_damage: int = 1
@export_range(40.0, 1000.0, 1.0) var turret_range: float = 360.0
@export_range(0.05, 5.0, 0.05) var turret_shot_windup: float = 0.45
@export_range(0.0, 10.0, 0.05) var turret_shot_cooldown: float = 0.8

@export_group("Turret Presentation")
@export_range(10.0, 120.0, 1.0) var turret_width: float = 42.0
@export_range(10.0, 140.0, 1.0) var turret_height: float = 48.0
@export_range(-120.0, 20.0, 1.0) var turret_bottom_y: float = -28.0
@export_range(8.0, 80.0, 1.0) var turret_barrel_length: float = 28.0
@export_range(0.0, 20.0, 0.5) var turret_recoil_distance: float = 5.0
@export_range(0.02, 1.0, 0.01) var turret_flash_duration: float = 0.1
@export_range(0.02, 1.0, 0.01) var turret_tracer_duration: float = 0.14
@export_range(0.05, 1.0, 0.05) var turret_inactive_alpha: float = 0.35
@export_range(0.0, 0.5, 0.01) var turret_radius_fill_alpha: float = 0.08


func get_max_count(type_id: int) -> int:
	match type_id:
		BuildableType.Id.MEDICAL_STATION:
			return medical_station_max_count
		BuildableType.Id.TURRET:
			return turret_max_count
		_:
			return 0


func is_reserved_cell(cell_index: int) -> bool:
	return reserved_cell_indices.has(cell_index)


func is_turret_cell(cell_index: int) -> bool:
	return turret_cell_indices.has(cell_index)


func is_medical_cell(cell_index: int) -> bool:
	return medical_station_cell_indices.has(cell_index)


func get_medical_cell_indices() -> Array[int]:
	return medical_station_cell_indices.duplicate()


func get_medical_footprint_cells(anchor_cell: int = -1) -> Array[int]:
	var resolved_cell: int = default_medical_cell if anchor_cell < 0 else anchor_cell
	if not is_medical_cell(resolved_cell):
		return []
	return [resolved_cell]


func get_footprint_cells(type_id: int, anchor_cell: int) -> Array[int]:
	if type_id == BuildableType.Id.MEDICAL_STATION:
		return get_medical_footprint_cells(anchor_cell)
	if type_id == BuildableType.Id.TURRET and is_turret_cell(anchor_cell):
		return [anchor_cell]
	return []
