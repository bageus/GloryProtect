class_name GroundOrbVisualController
extends Node2D

const GROUND_CORE_BASE_PATH: String = "res://visual/tiles/tile_ground_core_base.png"
const GROUND_CORE_ATLAS_PATH: String = "res://visual/tiles/atlas_ground_core_normal.png"

@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("GroundOrbRegistry") var registry_path: NodePath
@export_node_path("OrbContactSystem") var contact_system_path: NodePath
@export_node_path("ShieldSystem") var shield_system_path: NodePath
@export var platform_balance: PlatformBalance
@export var show_contact_zones: bool = false

@export_group("Ground Tiles")
@export var ground_tile_size: Vector2 = Vector2(128.0, 128.0)
@export_range(0.0, 24.0, 0.25) var ground_tile_overlap: float = 8.0
@export var ground_tile_vertical_offset: float = 0.0
@export_range(0.0, 2000.0, 10.0) var ground_spawn_route_margin: float = 760.0
@export var ground_grass_count_range: Vector2i = Vector2i(2, 4)
@export var ground_grass_max_size: Vector2 = Vector2(30.0, 30.0)
@export var ground_grass_vertical_range: Vector2 = Vector2(0.35, 0.82)
@export_range(0.0, 0.45, 0.01) var ground_grass_horizontal_margin_ratio: float = 0.12

@export_group("Ground Core")
@export_range(0.0, 1.0, 0.01) var alpha_crop_threshold: float = 0.08
@export var ground_core_size: Vector2 = Vector2(256.0, 128.0)
@export var ground_core_vertical_offset: float = 12.0
@export_range(1, 24, 1) var ground_core_frame_count: int = 6
@export_range(1.0, 30.0, 0.5) var ground_core_frame_rate: float = 8.0

@onready var _platform: PlatformController = get_node(platform_path)
@onready var _registry: GroundOrbRegistry = get_node(registry_path)
@onready var _contact: OrbContactSystem = get_node(contact_system_path)
@onready var _shield: ShieldSystem = get_node(shield_system_path)

var _game_flow: GameFlowController
var _surface_visual := GroundSurfaceVisual.new()
var _ground_core_base_texture: Texture2D
var _ground_core_atlas: Texture2D
var _ground_core_base_source_rect: Rect2
var _ground_core_frame_regions: Array[Rect2] = []
var _ground_core_animation_elapsed: float = 0.0


func _ready() -> void:
	assert(platform_balance != null, "GroundOrbVisualController requires PlatformBalance")
	_surface_visual.configure(alpha_crop_threshold)
	_ground_core_base_texture = _load_texture(GROUND_CORE_BASE_PATH)
	_ground_core_atlas = _load_texture(GROUND_CORE_ATLAS_PATH)
	if _ground_core_base_texture != null:
		_ground_core_base_source_rect = TextureRegionLayout.get_alpha_bounds(
			_ground_core_base_texture,
			alpha_crop_threshold
		)
	_ground_core_frame_regions.clear()
	if _ground_core_atlas != null:
		_ground_core_frame_regions = (
			TextureRegionLayout.get_auto_atlas_frame_regions(
				_ground_core_atlas,
				ground_core_frame_count,
				alpha_crop_threshold
			)
		)
	var scene_root: Node = get_tree().current_scene
	if scene_root != null:
		_game_flow = scene_root.get_node_or_null(
			"GameFlowController"
		) as GameFlowController
	queue_redraw()


func _process(delta: float) -> void:
	var simulation_active: bool = (
		_game_flow == null
		or _game_flow.is_world_simulation_active()
	)
	if simulation_active:
		_ground_core_animation_elapsed += maxf(0.0, delta)
	queue_redraw()


func _draw() -> void:
	_draw_ground()
	_draw_active_contact()
	for orb_id in range(_registry.get_orb_count()):
		_draw_orb(orb_id)


func _draw_ground() -> void:
	var platform_width: float = _platform.get_platform_width()
	_surface_visual.draw(
		self,
		get_ground_draw_min_x(platform_width),
		get_ground_draw_max_x(platform_width),
		_registry.catalog.ground_y,
		_registry.catalog.ground_depth,
		ground_tile_size,
		ground_tile_overlap,
		ground_tile_vertical_offset,
		ground_grass_count_range,
		ground_grass_max_size,
		ground_grass_vertical_range,
		ground_grass_horizontal_margin_ratio
	)


func get_ground_draw_min_x(platform_width: float) -> float:
	assert(platform_balance != null)
	return (
		platform_balance.world_min_x
		- maxf(0.0, platform_width) * 0.5
		- maxf(0.0, ground_spawn_route_margin)
	)


func get_ground_draw_max_x(platform_width: float) -> float:
	assert(platform_balance != null)
	return (
		platform_balance.world_max_x
		+ maxf(0.0, platform_width) * 0.5
		+ maxf(0.0, ground_spawn_route_margin)
	)


func _draw_orb(orb_id: int) -> void:
	var orb_world_position: Vector2 = _registry.get_orb_world_position(orb_id)
	var percent := _shield.get_health_percent(orb_id)
	var section_color := _shield.get_section_color(orb_id)
	var needs_attention := _shield.needs_direction_indicator(orb_id)
	var is_contact := _contact.get_active_orb_id() == orb_id

	var brightness := 0.32
	if needs_attention:
		brightness = 0.82
	if is_contact:
		brightness = 1.0
	if _shield.is_critical(orb_id):
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.012)
		brightness = maxf(brightness, pulse)

	if show_contact_zones:
		_draw_contact_zone(orb_id)

	_draw_ground_core(orb_world_position, is_contact, brightness)
	_draw_health_ring(orb_world_position, percent, section_color)


func _draw_ground_core(
	core_position: Vector2,
	is_charging: bool,
	brightness: float
) -> void:
	var texture: Texture2D = _ground_core_base_texture
	var source_rect: Rect2 = _ground_core_base_source_rect
	if (
		is_charging
		and _ground_core_atlas != null
		and not _ground_core_frame_regions.is_empty()
	):
		var frame_index: int = (
			floori(
				_ground_core_animation_elapsed
				* maxf(ground_core_frame_rate, 0.01)
			)
			% _ground_core_frame_regions.size()
		)
		texture = _ground_core_atlas
		source_rect = _ground_core_frame_regions[frame_index]
	if texture == null:
		return

	var draw_size: Vector2 = TextureRegionLayout.fit_inside(
		source_rect.size,
		ground_core_size
	)
	var center := core_position + Vector2(0.0, ground_core_vertical_offset)
	var visual_brightness: float = clampf(brightness, 0.55, 1.0)
	var tint := Color(
		visual_brightness,
		visual_brightness,
		visual_brightness,
		1.0
	)
	draw_texture_rect_region(
		texture,
		Rect2(center - draw_size * 0.5, draw_size),
		source_rect,
		tint
	)


func _draw_contact_zone(orb_id: int) -> void:
	var orb_x := _registry.get_world_x(orb_id)
	var half_width := _registry.catalog.contact_half_width
	var ground_y := _registry.catalog.ground_y
	var rect := Rect2(
		Vector2(orb_x - half_width, 0.0),
		Vector2(half_width * 2.0, ground_y)
	)
	draw_rect(rect, Color(0.14, 0.75, 0.88, 0.06), true)


func _draw_health_ring(
	orb_world_position: Vector2,
	percent: float,
	color: Color
) -> void:
	var ring_radius: float = maxf(
		_registry.catalog.orb_outer_radius + 7.0,
		ground_core_size.y * 0.5 + 8.0
	)
	var end_angle := -PI * 0.5 + TAU * clampf(percent / 100.0, 0.0, 1.0)
	draw_arc(
		orb_world_position + Vector2(0.0, ground_core_vertical_offset),
		ring_radius,
		-PI * 0.5,
		end_angle,
		48,
		color,
		4.0
	)


func _draw_active_contact() -> void:
	var orb_id := _contact.get_active_orb_id()
	if orb_id < 0:
		return
	var orb_position := _registry.get_orb_world_position(orb_id)
	var platform_orb_position := _platform.position
	draw_line(
		orb_position,
		platform_orb_position,
		Color(0.35, 0.93, 1.0, 0.7),
		8.0
	)
	draw_line(
		orb_position,
		platform_orb_position,
		Color(0.85, 1.0, 1.0, 0.95),
		2.0
	)


func _load_texture(resource_path: String) -> Texture2D:
	var resource: Resource = ResourceLoader.load(resource_path)
	var texture: Texture2D = resource as Texture2D
	if texture == null:
		push_error("GroundOrbVisualController could not load %s" % resource_path)
	return texture
