class_name BuildableGridVisual
extends Node2D

@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("BuildableGrid") var grid_path: NodePath
@export_node_path("BuildableInventory") var inventory_path: NodePath
@export_node_path("BuildableDebugInput") var debug_input_path: NodePath
@export_node_path("TurretDebugInput") var turret_input_path: NodePath
@export var balance: BuildableBalance

@onready var _platform: PlatformController = get_node(platform_path)
@onready var _grid: BuildableGrid = get_node(grid_path)
@onready var _inventory: BuildableInventory = get_node(inventory_path)
@onready var _debug_input: BuildableDebugInput = get_node(debug_input_path)
@onready var _turret_input: TurretDebugInput = get_node(turret_input_path)


func _ready() -> void:
	assert(balance != null, "BuildableGridVisual requires BuildableBalance")
	_grid.buildable_placed.connect(_on_visual_changed)
	_grid.buildable_moved.connect(_on_visual_changed)
	_grid.buildable_demolished.connect(_on_visual_changed)
	_grid.grid_reset.connect(_on_grid_reset)
	_inventory.buildable_unlocked.connect(_on_inventory_changed)
	_inventory.inventory_reset.connect(_on_grid_reset)
	_debug_input.selected_cell_changed.connect(_on_selected_cell_changed)
	_turret_input.selected_turret_changed.connect(_on_selected_turret_changed)
	queue_redraw()


func _draw() -> void:
	_draw_selected_cell()
	for snapshot: BuildableSnapshot in _grid.get_snapshots():
		match snapshot.type_id:
			BuildableType.Id.MEDICAL_STATION:
				_draw_medical_station(snapshot.local_x)
			BuildableType.Id.TURRET:
				_draw_turret(
					snapshot,
					snapshot.buildable_id == _turret_input.get_selected_turret_id()
				)


func _draw_selected_cell() -> void:
	var cell_index: int = _debug_input.get_selected_cell_index()
	var local_x: float = _platform.get_cell_local_x(cell_index)
	var top_y: float = -_platform.get_platform_height() * 0.5
	var color := Color(0.95, 0.34, 0.22, 0.8)
	if _grid.is_cell_available(cell_index):
		color = Color(0.25, 0.9, 0.72, 0.8)
	var occupied_id: int = _get_buildable_at_cell(cell_index)
	if occupied_id >= 0:
		color = Color(0.28, 0.8, 1.0, 0.9)
	var rect := Rect2(
		Vector2(
			local_x - _platform.balance.cell_width * 0.5,
			top_y
		),
		Vector2(_platform.balance.cell_width, _platform.get_platform_height())
	)
	draw_rect(rect, Color(color.r, color.g, color.b, 0.12), true)
	draw_rect(rect, color, false, 2.0)


func _get_buildable_at_cell(cell_index: int) -> int:
	for snapshot: BuildableSnapshot in _grid.get_snapshots():
		if snapshot.cell_index == cell_index:
			return snapshot.buildable_id
	return -1


func _draw_medical_station(local_x: float) -> void:
	var width: float = balance.medical_station_width
	var height: float = balance.medical_station_height
	var bottom_y: float = balance.medical_station_bottom_y
	var body := Rect2(
		Vector2(local_x - width * 0.5, bottom_y - height),
		Vector2(width, height)
	)
	draw_rect(body, Color(0.18, 0.35, 0.42), true)
	draw_rect(body, Color(0.52, 0.95, 0.88), false, 2.0)
	var cross_center := Vector2(local_x, body.position.y + 18.0)
	draw_rect(
		Rect2(cross_center + Vector2(-3.0, -10.0), Vector2(6.0, 20.0)),
		Color(0.92, 1.0, 0.98),
		true
	)
	draw_rect(
		Rect2(cross_center + Vector2(-10.0, -3.0), Vector2(20.0, 6.0)),
		Color(0.92, 1.0, 0.98),
		true
	)
	var shelf_y: float = body.end.y - 15.0
	draw_line(
		Vector2(body.position.x + 5.0, shelf_y),
		Vector2(body.end.x - 5.0, shelf_y),
		Color(0.62, 0.8, 0.82),
		2.0
	)


func _draw_turret(snapshot: BuildableSnapshot, selected: bool) -> void:
	var local_x: float = snapshot.local_x
	var width: float = balance.turret_width
	var height: float = balance.turret_height
	var bottom_y: float = balance.turret_bottom_y
	var base_rect := Rect2(
		Vector2(local_x - width * 0.5, bottom_y - 12.0),
		Vector2(width, 12.0)
	)
	draw_rect(base_rect, Color(0.25, 0.31, 0.42), true)
	draw_rect(base_rect, Color(0.68, 0.82, 0.96), false, 2.0)
	var center := Vector2(local_x, bottom_y - height * 0.58)
	draw_line(
		Vector2(local_x, base_rect.position.y),
		center,
		Color(0.52, 0.65, 0.78),
		8.0
	)
	draw_circle(center, width * 0.28, Color(0.22, 0.48, 0.67))
	draw_arc(
		center,
		width * 0.28,
		0.0,
		TAU,
		24,
		Color(0.76, 0.93, 1.0),
		2.0
	)
	draw_line(
		center,
		center + Vector2(width * 0.55, -4.0),
		Color(0.62, 0.82, 0.94),
		7.0
	)
	if selected:
		draw_arc(
			center,
			width * 0.43,
			0.0,
			TAU,
			32,
			Color(1.0, 0.84, 0.3),
			3.0
		)


func _on_visual_changed(_a: int, _b: int, _c: int) -> void:
	queue_redraw()


func _on_inventory_changed(_type_id: int, _count: int) -> void:
	queue_redraw()


func _on_selected_cell_changed(_cell_index: int) -> void:
	queue_redraw()


func _on_selected_turret_changed(_buildable_id: int) -> void:
	queue_redraw()


func _on_grid_reset() -> void:
	queue_redraw()
