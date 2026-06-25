class_name PlatformVisualController
extends Node2D

signal spawn_sequence_finished(defender_id: int)

const PORTAL_TEXTURE: Texture2D = preload(
	"res://visual/objects/portal/asset_portal_base.png"
)
const PORTAL_SPAWN1_TEXTURE: Texture2D = preload(
	"res://visual/objects/portal/overlay_portal_spawn_01.png"
)
const PORTAL_SPAWN2_TEXTURE: Texture2D = preload(
	"res://visual/objects/portal/overlay_portal_spawn_02.png"
)
const CAPTAIN_POST_TEXTURE_PATH := (
	"res://visual/objects/asset_captain_post_base.png"
)

enum PortalState {
	IDLE,
	FLASH,
	GHOST,
	FINISH,
}

@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("SteeringInputProvider") var steering_input_path: NodePath
@export var balance: PlatformBalance
@export var crew_balance: CrewBalance

@export_group("Asset Visuals")
@export_range(0.0, 4.0, 0.25) var platform_tile_overlap: float = 1.0
@export_range(0.0, 1.0, 0.01) var alpha_crop_threshold: float = 0.08
@export var show_cell_guides: bool = false
@export var platform_core_size: Vector2 = Vector2(112.0, 112.0)
@export_range(0.0, 1.0, 0.01) var platform_core_protrusion_ratio: float = 0.33
@export var platform_core_offset: Vector2 = Vector2.ZERO
@export_range(1, 24, 1) var platform_core_frame_count: int = 6
@export_range(1.0, 30.0, 0.5) var platform_core_frame_rate: float = 8.0
@export_range(0.05, 0.5, 0.01) var object_asset_scale: float = 0.24

@export_group("Driver Console")
@export var driver_console_surface_offset: Vector2 = Vector2(0.0, -2.0)

@export_group("Portal Visual")
@export var portal_surface_offset: Vector2 = Vector2(0.0, 2.0)
@export var portal_overlay_offset: Vector2 = Vector2(0.0, 2.0)
@export_range(0.01, 2.0, 0.01) var portal_flash_duration: float = 0.18
@export_range(0.01, 2.0, 0.01) var portal_ghost_duration: float = 0.26
@export_range(0.01, 2.0, 0.01) var portal_finish_duration: float = 0.26

@onready var _platform: PlatformController = get_node(platform_path)
@onready var _steering_input: SteeringInputProvider = get_node(steering_input_path)

var _game_flow: GameFlowController
var _surface_visual := PlatformSurfaceVisual.new()
var _portal_source_rect: Rect2
var _portal_spawn1_source_rect: Rect2
var _portal_spawn2_source_rect: Rect2
var _captain_post_texture: Texture2D
var _captain_post_source_rect: Rect2
var _portal_state: PortalState = PortalState.IDLE
var _portal_state_elapsed: float = 0.0
var _portal_active_defender_id: int = -1
var _portal_queue: Array[int] = []


func _ready() -> void:
	assert(balance != null, "PlatformVisualController requires PlatformBalance")
	assert(crew_balance != null, "PlatformVisualController requires CrewBalance")
	_surface_visual.configure(
		platform_core_frame_count,
		alpha_crop_threshold
	)
	_portal_source_rect = TextureRegionLayout.get_alpha_bounds(
		PORTAL_TEXTURE,
		alpha_crop_threshold
	)
	_portal_spawn1_source_rect = TextureRegionLayout.get_alpha_bounds(
		PORTAL_SPAWN1_TEXTURE,
		alpha_crop_threshold
	)
	_portal_spawn2_source_rect = TextureRegionLayout.get_alpha_bounds(
		PORTAL_SPAWN2_TEXTURE,
		alpha_crop_threshold
	)
	_captain_post_texture = load(CAPTAIN_POST_TEXTURE_PATH) as Texture2D
	if _captain_post_texture != null:
		_captain_post_source_rect = TextureRegionLayout.get_alpha_bounds(
			_captain_post_texture,
			alpha_crop_threshold
		)
	var scene_root: Node = get_tree().current_scene
	if scene_root != null:
		_game_flow = scene_root.get_node_or_null(
			"GameFlowController"
		) as GameFlowController
	_steering_input.driver_availability_changed.connect(_on_visual_state_changed)
	queue_redraw()


func _process(delta: float) -> void:
	var simulation_active: bool = (
		_game_flow == null
		or _game_flow.is_world_simulation_active()
	)
	if simulation_active:
		_surface_visual.advance(delta)
		_update_portal(delta)
	queue_redraw()


func play_spawn(defender_id: int) -> void:
	if defender_id < 0:
		return
	if defender_id == _portal_active_defender_id or _portal_queue.has(defender_id):
		return
	_portal_queue.append(defender_id)
	if _portal_state == PortalState.IDLE:
		_start_next_portal_sequence()


func is_portal_busy() -> bool:
	return _portal_state != PortalState.IDLE or not _portal_queue.is_empty()


func _draw() -> void:
	var platform_width: float = _platform.get_platform_width()
	_surface_visual.draw_body(
		self,
		platform_width,
		balance.platform_height,
		balance.cell_count,
		balance.cell_width,
		platform_tile_overlap
	)
	if show_cell_guides:
		_draw_cells(platform_width)
	_draw_portal()
	_draw_driver_console()
	_surface_visual.draw_core(
		self,
		balance.platform_height,
		platform_core_size,
		platform_core_protrusion_ratio,
		platform_core_offset,
		platform_core_frame_rate,
		_steering_input.driver_available
	)


func _draw_cells(platform_width: float) -> void:
	for index: int in range(1, balance.cell_count):
		var x: float = (
			-platform_width * 0.5 + float(index) * balance.cell_width
		)
		draw_line(
			Vector2(x, -balance.platform_height * 0.5),
			Vector2(x, balance.platform_height * 0.5),
			Color(0.82, 0.9, 0.96, 0.18),
			1.0
		)


func _draw_portal() -> void:
	var portal_size: Vector2 = _portal_source_rect.size * object_asset_scale
	var platform_top: float = -balance.platform_height * 0.5
	var portal_bottom := Vector2(
		crew_balance.replacement_door_local_x + portal_surface_offset.x,
		platform_top + portal_surface_offset.y
	)
	var center := portal_bottom - Vector2(0.0, portal_size.y * 0.5)
	var portal_rect := Rect2(center - portal_size * 0.5, portal_size)
	draw_texture_rect_region(
		PORTAL_TEXTURE,
		portal_rect,
		_portal_source_rect
	)

	if _portal_state == PortalState.IDLE:
		return

	# The first spawn layer remains visible through the whole sequence.
	_draw_portal_overlay(
		PORTAL_SPAWN1_TEXTURE,
		_portal_spawn1_source_rect,
		center
	)

	# The second frame is added on top without removing the first one.
	if _portal_state == PortalState.GHOST or _portal_state == PortalState.FINISH:
		_draw_portal_overlay(
			PORTAL_SPAWN2_TEXTURE,
			_portal_spawn2_source_rect,
			center
		)


func _draw_portal_overlay(
	texture: Texture2D,
	source_rect: Rect2,
	center: Vector2
) -> void:
	var overlay_size: Vector2 = source_rect.size * object_asset_scale
	var rect := Rect2(
		center + portal_overlay_offset - overlay_size * 0.5,
		overlay_size
	)
	draw_texture_rect_region(texture, rect, source_rect)


func _draw_driver_console() -> void:
	if _captain_post_texture == null:
		return
	var post_size: Vector2 = _captain_post_source_rect.size * object_asset_scale
	var platform_top: float = -balance.platform_height * 0.5
	var post_bottom := Vector2(
		driver_console_surface_offset.x,
		platform_top + driver_console_surface_offset.y
	)
	var post_rect := Rect2(
		post_bottom - Vector2(post_size.x * 0.5, post_size.y),
		post_size
	)
	var post_tint := Color.WHITE
	if not _steering_input.driver_available:
		post_tint = Color(0.55, 0.58, 0.62, 1.0)
	draw_texture_rect_region(
		_captain_post_texture,
		post_rect,
		_captain_post_source_rect,
		post_tint
	)


func _update_portal(delta: float) -> void:
	if _portal_state == PortalState.IDLE:
		return
	_portal_state_elapsed += maxf(0.0, delta)
	match _portal_state:
		PortalState.FLASH:
			if _portal_state_elapsed >= portal_flash_duration:
				_set_portal_state(PortalState.GHOST)
		PortalState.GHOST:
			if _portal_state_elapsed >= portal_ghost_duration:
				_set_portal_state(PortalState.FINISH)
		PortalState.FINISH:
			if _portal_state_elapsed >= portal_finish_duration:
				_finish_portal_sequence()


func _start_next_portal_sequence() -> void:
	if _portal_queue.is_empty():
		_portal_active_defender_id = -1
		_set_portal_state(PortalState.IDLE)
		return
	_portal_active_defender_id = _portal_queue.pop_front()
	_set_portal_state(PortalState.FLASH)


func _finish_portal_sequence() -> void:
	var completed_id: int = _portal_active_defender_id
	# The receiver creates the defender synchronously. Clear both overlays after that.
	spawn_sequence_finished.emit(completed_id)
	_portal_active_defender_id = -1
	_set_portal_state(PortalState.IDLE)
	call_deferred("_start_next_portal_sequence")


func _set_portal_state(new_state: PortalState) -> void:
	_portal_state = new_state
	_portal_state_elapsed = 0.0
	queue_redraw()


func _on_visual_state_changed(_is_available: bool) -> void:
	queue_redraw()
