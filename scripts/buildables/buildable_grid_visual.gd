class_name BuildableGridVisual
extends Node2D

@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("BuildableGrid") var grid_path: NodePath
@export_node_path("BuildableInventory") var inventory_path: NodePath
@export_node_path("BuildableDebugInput") var debug_input_path: NodePath
@export_node_path("TurretDebugInput") var turret_input_path: NodePath
@export_node_path("TurretSystem") var turret_system_path: NodePath = NodePath("../../TurretSystem")
@export_node_path("BoardingEnemyRegistry") var enemy_registry_path: NodePath = NodePath("../../BoardingEnemyRegistry")
@export var balance: BuildableBalance
@export var medical_post_surface_offset: Vector2 = Vector2.ZERO

@onready var _platform: PlatformController = get_node(platform_path)
@onready var _grid: BuildableGrid = get_node(grid_path)
@onready var _inventory: BuildableInventory = get_node(inventory_path)
@onready var _debug_input: BuildableDebugInput = get_node(debug_input_path)
@onready var _turret_input: TurretDebugInput = get_node(turret_input_path)
@onready var _turrets: TurretSystem = get_node(turret_system_path)
@onready var _enemies: BoardingEnemyRegistry = get_node(enemy_registry_path)


func _ready() -> void:
	assert(balance != null, "BuildableGridVisual requires BuildableBalance")
	_grid.buildable_placed.connect(_on_visual_changed)
	_grid.buildable_moved.connect(_on_visual_changed)
	_grid.buildable_demolished.connect(_on_visual_changed)
	_grid.grid_reset.connect(_on_grid_reset)
	_inventory.buildable_unlocked.connect(_on_inventory_changed)
	_inventory.inventory_reset.connect(_on_grid_reset)
	_debug_input.selected_cell_changed.connect(_on_selected_cell_changed)
	_create_turret_visual()
	queue_redraw()


func _draw() -> void:
	_draw_selected_cell()
	for snapshot: BuildableSnapshot in _grid.get_snapshots():
		if snapshot.type_id == BuildableType.Id.MEDICAL_STATION:
			_draw_medical_station(snapshot.local_x)


func _create_turret_visual() -> void:
	var turret_visual := TurretVisualController.new()
	turret_visual.name = "TurretVisualController"
	turret_visual.configure(
		_platform,
		_grid,
		_turrets,
		_turret_input,
		_enemies,
		balance
	)
	add_child(turret_visual)


func _draw_selected_cell() -> void:
	var cell_index: int = _debug_input.get_selected_cell_index()
	var local_x: float = _platform.get_cell_local_x(cell_index)
	var top_y: float = -_platform.get_platform_height() * 0.5
	var color := Color(0.95, 0.34, 0.22, 0.8)
	if _grid.is_cell_available_for_type(BuildableType.Id.TURRET, cell_index):
		color = Color(0.25, 0.9, 0.72, 0.8)
	if _get_buildable_at_cell(cell_index) >= 0:
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
	var bottom_center := Vector2(
		local_x + medical_post_surface_offset.x,
		balance.medical_station_bottom_y + medical_post_surface_offset.y
	)
	var station_size := Vector2(
		balance.medical_station_width,
		balance.medical_station_height
	)
	var station_rect := Rect2(
		bottom_center - Vector2(station_size.x * 0.5, station_size.y),
		station_size
	)
	var frame_color := Color(0.32, 0.9, 0.76, 1.0)
	draw_rect(station_rect, Color(0.07, 0.14, 0.16, 0.96), true)
	draw_rect(station_rect, frame_color, false, 3.0)
	var cross_center := station_rect.get_center() + Vector2(0.0, -4.0)
	draw_rect(
		Rect2(cross_center + Vector2(-4.0, -13.0), Vector2(8.0, 26.0)),
		frame_color,
		true
	)
	draw_rect(
		Rect2(cross_center + Vector2(-13.0, -4.0), Vector2(26.0, 8.0)),
		frame_color,
		true
	)
	draw_line(
		station_rect.position + Vector2(6.0, station_rect.size.y - 10.0),
		station_rect.end - Vector2(6.0, 10.0),
		Color(0.18, 0.46, 0.42),
		3.0
	)


func _on_visual_changed(_a: int, _b: int, _c: int) -> void:
	queue_redraw()


func _on_inventory_changed(_type_id: int, _count: int) -> void:
	queue_redraw()


func _on_selected_cell_changed(_cell_index: int) -> void:
	queue_redraw()


func _on_grid_reset() -> void:
	queue_redraw()
