class_name PlatformVisualController
extends Node2D

signal spawn_sequence_finished(defender_id: int)

const PLATFORM_TILE_TEXTURE: Texture2D = preload(
	"res://visual/tiles/tile_platform.png"
)
const PLATFORM_CORE_TEXTURE: Texture2D = preload(
	"res://visual/tiles/tile_core_platform_energy.png"
)
const PORTAL_TEXTURE: Texture2D = preload(
	"res://visual/objects/portal/asset_object_portal.png"
)
const PORTAL_SPAWN1_TEXTURE: Texture2D = preload(
	"res://visual/objects/portal/overlay_object_portal_spawn1.png"
)
const PORTAL_SPAWN2_TEXTURE: Texture2D = preload(
	"res://visual/objects/portal/overlay_object_portal_spawn2.png"
)
const DRIVER_TOGGLE_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_object_toggle.png"
)
const DRIVER_LEVER_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_object_pry.png"
)

const ALPHA_CROP_THRESHOLD: float = 0.08

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
@export var show_cell_guides: bool = false
@export var platform_core_size: Vector2 = Vector2(112.0, 112.0)
@export_range(0.0, 1.0, 0.01) var platform_core_protrusion_ratio: float = 0.33
@export var platform_core_offset: Vector2 = Vector2.ZERO
@export_range(0.05, 0.5, 0.01) var object_asset_scale: float = 0.24

@export_group("Driver Console")
@export var driver_console_surface_offset: Vector2 = Vector2(0.0, -2.0)
@export var driver_lever_mount_normalized: Vector2 = Vector2(0.5, 0.58)
@export var driver_lever_mount_offset: Vector2 = Vector2(0.0, 0.0)
@export_range(0.0, 60.0, 1.0) var driver_lever_max_angle_degrees: float = 24.0
@export_range(1.0, 30.0, 0.5) var driver_lever_response_speed: float = 13.0

@export_group("Portal Visual")
@export var portal_surface_offset: Vector2 = Vector2(0.0, 2.0)
@export var portal_overlay_offset: Vector2 = Vector2(0.0, 2.0)
@export_range(0.01, 2.0, 0.01) var portal_flash_duration: float = 0.18
@export_range(0.01, 2.0, 0.01) var portal_ghost_duration: float = 0.26
@export_range(0.01, 2.0, 0.01) var portal_finish_duration: float = 0.26

@onready var _platform: PlatformController = get_node(platform_path)
@onready var _steering_input: SteeringInputProvider = get_node(steering_input_path)

var _game_flow: GameFlowController
var _platform_tile_source_rect: Rect2
var _portal_source_rect: Rect2
var _portal_spawn1_source_rect: Rect2
var _portal_spawn2_source_rect: Rect2
var _driver_toggle_source_rect: Rect2
var _driver_lever_source_rect: Rect2
var _driver_lever_angle: float = 0.0
var _portal_state: PortalState = PortalState.IDLE
var _portal_state_elapsed: float = 0.0
var _portal_active_defender_id: int = -1
var _portal_queue: Array[int] = []


func _ready() -> void:
	assert(balance != null, "PlatformVisualController requires PlatformBalance")
	assert(crew_balance != null, "PlatformVisualController requires CrewBalance")
	_platform_tile_source_rect = _get_used_texture_rect(PLATFORM_TILE_TEXTURE)
	_portal_source_rect = _get_alpha_bounds(PORTAL_TEXTURE)
	_portal_spawn1_source_rect = _get_alpha_bounds(PORTAL_SPAWN1_TEXTURE)
	_portal_spawn2_source_rect = _get_alpha_bounds(PORTAL_SPAWN2_TEXTURE)
	_driver_toggle_source_rect = _get_alpha_bounds(DRIVER_TOGGLE_TEXTURE)
	_driver_lever_source_rect = _get_alpha_bounds(DRIVER_LEVER_TEXTURE)
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
		_update_driver_lever(delta)
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
	var platform_rect := Rect2(
		Vector2(-platform_width * 0.5, -balance.platform_height * 0.5),
		Vector2(platform_width, balance.platform_height)
	)

	draw_rect(platform_rect, Color(0.12, 0.17, 0.24), true)
	_draw_platform_tiles(platform_width)
	draw_rect(platform_rect, Color(0.55, 0.69, 0.82, 0.45), false, 2.0)
	if show_cell_guides:
		_draw_cells(platform_width)
	_draw_portal()
	_draw_driver_console()
	_draw_platform_orb()


func _draw_platform_tiles(platform_width: float) -> void:
	var first_x: float = -platform_width * 0.5
	var half_overlap: float = platform_tile_overlap * 0.5
	for index: int in range(balance.cell_count):
		var tile_rect := Rect2(
			Vector2(
				first_x + float(index) * balance.cell_width - half_overlap,
				-balance.platform_height * 0.5
			),
			Vector2(
				balance.cell_width + platform_tile_overlap,
				balance.platform_height
			)
		)
		draw_texture_rect_region(
			PLATFORM_TILE_TEXTURE,
			tile_rect,
			_platform_tile_source_rect
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
	if _portal_state == PortalState.FLASH:
		var progress: float = clampf(
			_portal_state_elapsed / maxf(portal_flash_duration, 0.01),
			0.0,
			1.0
		)
		_draw_portal_overlay(
			PORTAL_SPAWN1_TEXTURE,
			_portal_spawn1_source_rect,
			center,
			Color(1.0, 1.0, 1.0, sin(progress * PI))
		)
		return

	var ghost_alpha: float = 0.38
	if _portal_state == PortalState.FINISH:
		ghost_alpha = lerpf(
			0.5,
			0.88,
			clampf(
				_portal_state_elapsed / maxf(portal_finish_duration, 0.01),
				0.0,
				1.0
			)
		)
	_draw_portal_defender_ghost(center + Vector2(0.0, 6.0), ghost_alpha)

	if _portal_state == PortalState.FINISH:
		var finish_progress: float = clampf(
			_portal_state_elapsed / maxf(portal_finish_duration, 0.01),
			0.0,
			1.0
		)
		_draw_portal_overlay(
			PORTAL_SPAWN2_TEXTURE,
			_portal_spawn2_source_rect,
			center,
			Color(1.0, 1.0, 1.0, sin(finish_progress * PI))
		)


func _draw_portal_overlay(
	texture: Texture2D,
	source_rect: Rect2,
	center: Vector2,
	modulate: Color
) -> void:
	var overlay_size: Vector2 = source_rect.size * object_asset_scale
	var rect := Rect2(
		center + portal_overlay_offset - overlay_size * 0.5,
		overlay_size
	)
	draw_texture_rect_region(texture, rect, source_rect, modulate)


func _draw_portal_defender_ghost(center: Vector2, alpha: float) -> void:
	var color: Color = _get_portal_defender_color(_portal_active_defender_id)
	color.a = alpha
	var outline := Color(0.75, 0.96, 1.0, alpha * 0.9)
	draw_circle(center + Vector2(0.0, -24.0), 10.0, color)
	draw_rect(
		Rect2(center + Vector2(-10.0, -14.0), Vector2(20.0, 30.0)),
		color,
		true
	)
	draw_line(
		center + Vector2(-7.0, 16.0),
		center + Vector2(-10.0, 31.0),
		color,
		6.0,
		true
	)
	draw_line(
		center + Vector2(7.0, 16.0),
		center + Vector2(10.0, 31.0),
		color,
		6.0,
		true
	)
	draw_arc(center + Vector2(0.0, -24.0), 11.5, 0.0, TAU, 20, outline, 2.0)


func _draw_driver_console() -> void:
	var console_size: Vector2 = (
		_driver_toggle_source_rect.size * object_asset_scale
	)
	var lever_size: Vector2 = (
		_driver_lever_source_rect.size * object_asset_scale
	)
	var platform_top: float = -balance.platform_height * 0.5
	var console_bottom := Vector2(
		driver_console_surface_offset.x,
		platform_top + driver_console_surface_offset.y
	)
	var console_rect := Rect2(
		console_bottom - Vector2(console_size.x * 0.5, console_size.y),
		console_size
	)
	var console_tint := Color.WHITE
	if not _steering_input.driver_available:
		console_tint = Color(0.55, 0.58, 0.62, 1.0)
	draw_texture_rect_region(
		DRIVER_TOGGLE_TEXTURE,
		console_rect,
		_driver_toggle_source_rect,
		console_tint
	)

	var lever_mount := Vector2(
		console_rect.position.x
			+ console_rect.size.x * driver_lever_mount_normalized.x,
		console_rect.position.y
			+ console_rect.size.y * driver_lever_mount_normalized.y
	) + driver_lever_mount_offset
	var lever_rect := Rect2(
		Vector2(-lever_size.x * 0.5, -lever_size.y),
		lever_size
	)
	draw_set_transform(lever_mount, _driver_lever_angle, Vector2.ONE)
	draw_texture_rect_region(
		DRIVER_LEVER_TEXTURE,
		lever_rect,
		_driver_lever_source_rect,
		console_tint
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_platform_orb() -> void:
	var core_tint := Color.WHITE
	if not _steering_input.driver_available:
		core_tint = Color(0.42, 0.46, 0.5, 1.0)

	var platform_bottom: float = balance.platform_height * 0.5
	var core_center_y: float = (
		platform_bottom
		+ (platform_core_protrusion_ratio - 0.5) * platform_core_size.y
	)
	var core_center := Vector2(0.0, core_center_y) + platform_core_offset
	var core_rect := Rect2(
		core_center - platform_core_size * 0.5,
		platform_core_size
	)
	draw_texture_rect(
		PLATFORM_CORE_TEXTURE,
		core_rect,
		false,
		core_tint
	)


func _update_driver_lever(delta: float) -> void:
	var steering_axis: float = _steering_input.get_steering_axis()
	var maximum_angle: float = deg_to_rad(driver_lever_max_angle_degrees)
	var target_angle: float = steering_axis * maximum_angle
	_driver_lever_angle = lerp_angle(
		_driver_lever_angle,
		target_angle,
		clampf(delta * driver_lever_response_speed, 0.0, 1.0)
	)
	if absf(_driver_lever_angle - target_angle) <= 0.0005:
		_driver_lever_angle = target_angle


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
	_portal_active_defender_id = -1
	_set_portal_state(PortalState.IDLE)
	spawn_sequence_finished.emit(completed_id)
	call_deferred("_start_next_portal_sequence")


func _set_portal_state(new_state: PortalState) -> void:
	_portal_state = new_state
	_portal_state_elapsed = 0.0
	queue_redraw()


func _get_portal_defender_color(defender_id: int) -> Color:
	var colors: Array[Color] = [
		Color(0.35, 0.84, 1.0),
		Color(1.0, 0.68, 0.32),
		Color(0.58, 0.92, 0.48),
		Color(0.86, 0.5, 1.0),
	]
	return colors[maxi(0, defender_id) % colors.size()]


func _get_used_texture_rect(texture: Texture2D) -> Rect2:
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return Rect2(Vector2.ZERO, texture.get_size())
	var used_rect: Rect2i = image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return Rect2(Vector2.ZERO, texture.get_size())
	return Rect2(
		Vector2(used_rect.position),
		Vector2(used_rect.size)
	)


func _get_alpha_bounds(texture: Texture2D) -> Rect2:
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return Rect2(Vector2.ZERO, texture.get_size())
	var width: int = image.get_width()
	var height: int = image.get_height()
	var min_x: int = width
	var min_y: int = height
	var max_x: int = -1
	var max_y: int = -1
	for y: int in range(height):
		for x: int in range(width):
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


func _on_visual_state_changed(_is_available: bool) -> void:
	queue_redraw()
