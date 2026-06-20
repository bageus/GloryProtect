class_name BuildableBalance
extends Resource

@export_group("Inventory")
@export_range(0, 8, 1) var medical_station_max_count: int = 1
@export_range(0, 32, 1) var default_medical_cell: int = 11
@export var reserved_cell_indices: Array[int] = [1, 6, 7, 8, 9, 16]

@export_group("Medical Station")
@export_range(0.1, 30.0, 0.1) var heal_interval: float = 5.0
@export_range(1, 10, 1) var heal_amount: int = 1
@export_range(1.0, 120.0, 1.0) var heal_range: float = 18.0
@export_range(10.0, 100.0, 1.0) var medical_station_width: float = 34.0
@export_range(20.0, 160.0, 1.0) var medical_station_height: float = 66.0
@export_range(-120.0, 20.0, 1.0) var medical_station_bottom_y: float = -28.0


func get_max_count(type_id: int) -> int:
	match type_id:
		BuildableType.Id.MEDICAL_STATION:
			return medical_station_max_count
		BuildableType.Id.TURRET:
			return 0
		_:
			return 0


func is_reserved_cell(cell_index: int) -> bool:
	return reserved_cell_indices.has(cell_index)
