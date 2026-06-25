class_name BuildableGridVisual
extends Node2D

const MEDICAL_POST_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_heal_post_base.png"
)
const ALPHA_CROP_THRESHOLD: float = 0.08
const MEDICAL_FLASH_DURATION: float = 0.4

@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("BuildableGrid") var grid_path: NodePath
@export_node_path("BuildableInventory") var inventory_path: NodePath
@export_node_path("BuildableDebugInput") var debug_input_path: NodePath
@export_node_path("TurretDebugInput") var turret_input_path: NodePath
@export_node_path("BuildablePlacementController") var placement_controller_path: NodePath
@export_node_path("TurretSystem") var turret_system_path: NodePath = NodePath("../../TurretSystem")
@export_node_path("BoardingEnemyRegistry") var enemy_registry_path: NodePath = NodePath("../../BoardingEnemyRegistry")
@export_node_path("MedicalStationSystem") var medical_system_path: NodePath = NodePath("../../MedicalStationSystem")
@export var balance: BuildableBalance
@export_range(0.05, 0.5, 0.01) var medical_post_scale: float = 0.24
@export var medical_post_surface_offset: Vector2 = Vector2.ZERO

@onready var _platform: PlatformController = get_node(platform_path)
@onready var _grid: BuildableGrid = get_node(grid_path)
@onready var _inventory: BuildableInventory = get_node(inventory_path)
@onready var _debug_input: BuildableDebugInput = get_node_or_null(
	debug_input_path
) as BuildableDebugInput
@onready var _turret_input: TurretDebugInput = get_node(turret_input_path)
@onready var _placement: BuildablePlacementController = get_node_or_null(
	placement_controller_path
) as BuildablePlacementController
@onready var _turrets: TurretSystem = get_node(turret_system_path)
@onready var _enemies: BoardingEnemyRegistry = get_node(enemy_registry_path)
@onready var _medical: MedicalStationSystem = get_node(medical_system_path)

var _medical_source_rect: Rect2
var _medical_cycle_active: bool = false
var _medical_cycle_remaining: float = 0.0
var _medical_cycle_total: float = 0.0
var _medical_flash_remaining: float = 0.0
var _visual_elapsed: float = 0.0


func _ready() -> void:
	assert(balance != null, "BuildableGridVisual requires BuildableBalance")
	_medical_source_rect = _get_alpha_bounds(MEDICAL_POST_TEXTURE)
	_grid.buildable_placed.connect(_on_visual_changed)
	_grid.buildable_moved.connect(_on_visual_changed)
	_grid.buildable_demolished.connect(_on_visual_changed)
	_grid.grid_reset.connect(_on_grid_reset)
	_inventory.buildable_unlocked.connect(_on_inventory_changed)
	_inventory.inventory_reset.connect(_on_grid_reset)
	_medical.healing_started.connect(_on_healing_started)
	_medical.healing_progress.connect(_on_healing_progress)
	_medical.segment_restored.connect(_on_segment_restored)
	_medical.healing_stopped.connect(_on_healing_stopped)
	if _placement != null:
		_placement.mode_changed.connect(_on_placement_changed)
		_placement.hovered_cell_changed.connect(_on_selected_cell_changed)
		_placement.selected_buildable_changed.connect(_on_selected_buildable_changed)
	elif _debug_input != null:
		_debug_input.selected_cell_changed.connect(_on_selected_cell_changed)
	_create_turret_visual()
	queue_redraw()


func _process(delta: float) -> void:
	var changed: bool = false
	if _medical_cycle_active:
		_visual_elapsed += maxf(0.0, delta)
		changed = true
	if _medical_flash_remaining > 0.0:
		_medical_flash_remaining = maxf(
			0.0,
			_medical_flash_remaining - maxf(0.0, delta)
		)
		changed = true
	if changed:
		queue_redraw()


func _draw() -> void:
	if _placement != null and _placement.is_grid_preview_visible():
		_draw_placement_grid()
	elif _debug_input != null:
		_draw_selected_cell()
	for snapshot: BuildableSnapshot in _grid.get_snapshots():
		if snapshot.type_id == BuildableType.Id.MEDICAL_STATION:
			_draw_medical_station(
				snapshot,
				_placement != null
				and snapshot.buildable_id == _placement.get_selected_buildable_id()
			)


func is_medical_cycle_visual_active() -> bool:
	return _medical_cycle_active


func get_medical_cycle_progress() -> float:
	if not _medical_cycle_active or _medical_cycle_total <= 0.0:
		return 0.0
	return clampf(
		1.0 - _medical_cycle_remaining / _medical_cycle_total,
		0.0,
		1.0
	)


func get_medical_flash_remaining() -> float:
	return _medical_flash_remaining


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


func _draw_placement_grid() -> void:
	var hovered_cell := _placement.get_hovered_cell_index()
	var selected_id := _placement.get_selected_buildable_id()
	for cell_index: int in range(_platform.get_cell_count()):
		var occupant_id := _grid.get_buildable_id_at_cell(cell_index)
		var reason := _placement.get_cell_unavailability_reason(cell_index)
		var color := Color(0.32, 0.35, 0.4, 0.72)
		if reason == &"":
			color = Color(0.24, 0.9, 0.62, 0.86)
		elif reason == BuildableGrid.REASON_CELL_OCCUPIED:
			color = Color(0.25, 0.72, 1.0, 0.88)
		elif reason == BuildableGrid.REASON_CELL_NOT_ALLOWED:
			color = Color(0.65, 0.28, 0.3, 0.62)
		else:
			color = Color(0.92, 0.42, 0.24, 0.76)
		if occupant_id >= 0:
			color = Color(0.25, 0.72, 1.0, 0.88)
		if occupant_id == selected_id:
			color = Color(1.0, 0.82, 0.25, 0.95)
		var fill_alpha := 0.1
		var line_width := 1.5
		if cell_index == hovered_cell:
			fill_alpha = 0.24
			line_width = 3.0
		var rect := _platform.get_cell_rect_local(cell_index)
		draw_rect(rect, Color(color.r, color.g, color.b, fill_alpha), true)
		draw_rect(rect, color, false, line_width)


func _draw_selected_cell() -> void:
	var cell_index: int = _debug_input.get_selected_cell_index()
	var color := Color(0.95, 0.34, 0.22, 0.8)
	if _grid.is_cell_available_for_type(BuildableType.Id.TURRET, cell_index):
		color = Color(0.25, 0.9, 0.72, 0.8)
	if _grid.get_buildable_id_at_cell(cell_index) >= 0:
		color = Color(0.28, 0.8, 1.0, 0.9)
	var rect := _platform.get_cell_rect_local(cell_index)
	draw_rect(rect, Color(color.r, color.g, color.b, 0.12), true)
	draw_rect(rect, color, false, 2.0)


func _draw_medical_station(snapshot: BuildableSnapshot, selected: bool) -> void:
	var asset_size: Vector2 = _medical_source_rect.size * medical_post_scale
	var bottom_center := Vector2(
		snapshot.local_x + medical_post_surface_offset.x,
		balance.medical_station_bottom_y + medical_post_surface_offset.y
	)
	var rect := Rect2(
		bottom_center - Vector2(asset_size.x * 0.5, asset_size.y),
		asset_size
	)
	if _medical_cycle_active:
		_draw_medical_active_glow(rect)
	draw_texture_rect_region(
		MEDICAL_POST_TEXTURE,
		rect,
		_medical_source_rect
	)
	_draw_medical_status(rect)
	if _medical_flash_remaining > 0.0:
		var flash_ratio := clampf(
			_medical_flash_remaining / MEDICAL_FLASH_DURATION,
			0.0,
			1.0
		)
		draw_rect(
			rect.grow(5.0 + flash_ratio * 5.0),
			Color(0.7, 1.0, 0.82, flash_ratio),
			false,
			2.0 + flash_ratio * 2.0
		)
	if selected:
		draw_rect(rect.grow(4.0), Color(1.0, 0.84, 0.3), false, 3.0)


func _draw_medical_active_glow(rect: Rect2) -> void:
	var pulse := 0.5 + 0.5 * sin(_visual_elapsed * 6.0)
	var center := rect.get_center() + Vector2(0.0, rect.size.y * 0.08)
	draw_circle(
		center,
		maxf(rect.size.x, rect.size.y) * (0.42 + pulse * 0.04),
		Color(0.28, 1.0, 0.62, 0.08 + pulse * 0.1)
	)


func _draw_medical_status(rect: Rect2) -> void:
	var center := rect.position + Vector2(rect.size.x * 0.5, 10.0)
	var indicator := Color(0.45, 0.55, 0.58, 0.9)
	if _medical_cycle_active:
		indicator = Color(0.28, 1.0, 0.62, 1.0)
	draw_circle(center, 4.0, indicator)
	if not _medical_cycle_active:
		return
	var progress := get_medical_cycle_progress()
	draw_arc(
		center,
		9.0,
		-PI * 0.5,
		-PI * 0.5 + TAU * progress,
		24,
		Color(0.72, 1.0, 0.84, 1.0),
		2.5
	)


func _get_alpha_bounds(texture: Texture2D) -> Rect2:
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return Rect2(Vector2.ZERO, texture.get_size())
	var min_x: int = image.get_width()
	var min_y: int = image.get_height()
	var max_x: int = -1
	var max_y: int = -1
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a <= ALPHA_CROP_THRESHOLD:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2(Vector2.ZERO, texture.get_size())
	return Rect2(
		Vector2(float(min_x), float(min_y)),
		Vector2(
			float(max_x - min_x + 1),
			float(max_y - min_y + 1)
		)
	)


func _reset_medical_visual_state() -> void:
	_medical_cycle_active = false
	_medical_cycle_remaining = 0.0
	_medical_cycle_total = 0.0
	_medical_flash_remaining = 0.0
	_visual_elapsed = 0.0


func _on_healing_started(_medic_id: int, _target_id: int) -> void:
	_medical_cycle_active = true
	_medical_cycle_remaining = 0.0
	_medical_cycle_total = 0.0
	_visual_elapsed = 0.0
	queue_redraw()


func _on_healing_progress(
	_medic_id: int,
	_target_id: int,
	remaining: float
) -> void:
	var safe_remaining := maxf(0.0, remaining)
	_medical_cycle_active = true
	if _medical_cycle_total <= 0.0 or safe_remaining > _medical_cycle_total:
		_medical_cycle_total = maxf(0.01, safe_remaining)
	_medical_cycle_remaining = safe_remaining
	queue_redraw()


func _on_segment_restored(
	_medic_id: int,
	_target_id: int,
	_amount: int
) -> void:
	_medical_flash_remaining = MEDICAL_FLASH_DURATION
	queue_redraw()


func _on_healing_stopped(_medic_id: int, _target_id: int) -> void:
	_medical_cycle_active = false
	_medical_cycle_remaining = 0.0
	_medical_cycle_total = 0.0
	queue_redraw()


func _on_visual_changed(_a: int, _b: int, _c: int) -> void:
	queue_redraw()


func _on_inventory_changed(_type_id: int, _count: int) -> void:
	queue_redraw()


func _on_selected_cell_changed(_cell_index: int) -> void:
	queue_redraw()


func _on_selected_buildable_changed(_buildable_id: int) -> void:
	queue_redraw()


func _on_placement_changed(_mode: int, _type_id: int, _buildable_id: int) -> void:
	queue_redraw()


func _on_grid_reset() -> void:
	_reset_medical_visual_state()
	queue_redraw()
