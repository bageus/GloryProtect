class_name GroundOrbVisualController
extends Node2D

const GROUND_TILE_TEXTURE: Texture2D = preload(
	"res://visual/tiles/tile_grass.png"
)

# The asset names describe the source half, while the supplied visual mapping is
# reversed: *_right_* is the left screen half and *_left_* is the right half.
const GROUND_CORE_VISUAL_LEFT_ENERGY_TEXTURE: Texture2D = preload(
	"res://visual/tiles/tile_core_ground_right_energy.png"
)
const GROUND_CORE_VISUAL_LEFT_NOENERGY_TEXTURE: Texture2D = preload(
	"res://visual/tiles/tile_core_ground_right_noenergy.png"
)
const GROUND_CORE_VISUAL_RIGHT_ENERGY_TEXTURE: Texture2D = preload(
	"res://visual/tiles/tile_core_ground_left_energy.png"
)
const GROUND_CORE_VISUAL_RIGHT_NOENERGY_TEXTURE: Texture2D = preload(
	"res://visual/tiles/tile_core_ground_left_noenergy.png"
)

@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("GroundOrbRegistry") var registry_path: NodePath
@export_node_path("OrbContactSystem") var contact_system_path: NodePath
@export_node_path("ShieldSystem") var shield_system_path: NodePath
@export var platform_balance: PlatformBalance
@export var show_contact_zones: bool = false

@export_group("Asset Visuals")
@export var ground_tile_size: Vector2 = Vector2(128.0, 128.0)
@export_range(0.0, 8.0, 0.25) var ground_tile_overlap: float = 1.0
@export var ground_tile_vertical_offset: float = 0.0
@export var ground_core_half_size: Vector2 = Vector2(96.0, 128.0)
@export var ground_core_vertical_offset: float = 0.0

@onready var _platform: PlatformController = get_node(platform_path)
@onready var _registry: GroundOrbRegistry = get_node(registry_path)
@onready var _contact: OrbContactSystem = get_node(contact_system_path)
@onready var _shield: ShieldSystem = get_node(shield_system_path)

var _ground_tile_source_rect: Rect2


func _ready() -> void:
	assert(platform_balance != null, "GroundOrbVisualController requires PlatformBalance")
	_ground_tile_source_rect = _get_used_texture_rect(GROUND_TILE_TEXTURE)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	_draw_ground()
	_draw_active_contact()
	for orb_id in range(_registry.get_orb_count()):
		_draw_orb(orb_id)


func _draw_ground() -> void:
	var ground_y := _registry.catalog.ground_y
	var ground_rect := Rect2(
		Vector2(platform_balance.world_min_x, ground_y),
		Vector2(
			platform_balance.world_max_x - platform_balance.world_min_x,
			_registry.catalog.ground_depth
		)
	)
	draw_rect(ground_rect, Color(0.045, 0.065, 0.08), true)

	var tile_width: float = maxf(ground_tile_size.x, 1.0)
	var half_overlap: float = ground_tile_overlap * 0.5
	var tile_x: float = (
		floorf(platform_balance.world_min_x / tile_width) * tile_width
	)
	while tile_x < platform_balance.world_max_x:
		var tile_rect := Rect2(
			Vector2(
				tile_x - half_overlap,
				ground_y + ground_tile_vertical_offset
			),
			Vector2(
				ground_tile_size.x + ground_tile_overlap,
				ground_tile_size.y
			)
		)
		draw_texture_rect_region(
			GROUND_TILE_TEXTURE,
			tile_rect,
			_ground_tile_source_rect
		)
		tile_x += tile_width


func _draw_orb(orb_id: int) -> void:
	var position := _registry.get_orb_world_position(orb_id)
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

	_draw_ground_core(position, is_contact, brightness)
	_draw_health_ring(position, percent, section_color)


func _draw_ground_core(
	position: Vector2,
	is_charging: bool,
	brightness: float
) -> void:
	var visual_left_texture: Texture2D = (
		GROUND_CORE_VISUAL_LEFT_ENERGY_TEXTURE
		if is_charging
		else GROUND_CORE_VISUAL_LEFT_NOENERGY_TEXTURE
	)
	var visual_right_texture: Texture2D = (
		GROUND_CORE_VISUAL_RIGHT_ENERGY_TEXTURE
		if is_charging
		else GROUND_CORE_VISUAL_RIGHT_NOENERGY_TEXTURE
	)
	var visual_brightness: float = clampf(brightness, 0.55, 1.0)
	var tint := Color(
		visual_brightness,
		visual_brightness,
		visual_brightness,
		1.0
	)
	var center := position + Vector2(0.0, ground_core_vertical_offset)
	var half_height: float = ground_core_half_size.y * 0.5
	var left_rect := Rect2(
		center + Vector2(-ground_core_half_size.x, -half_height),
		ground_core_half_size
	)
	var right_rect := Rect2(
		center + Vector2(0.0, -half_height),
		ground_core_half_size
	)

	draw_texture_rect(visual_left_texture, left_rect, false, tint)
	draw_texture_rect(visual_right_texture, right_rect, false, tint)


func _draw_contact_zone(orb_id: int) -> void:
	var orb_x := _registry.get_world_x(orb_id)
	var half_width := _registry.catalog.contact_half_width
	var ground_y := _registry.catalog.ground_y
	var rect := Rect2(
		Vector2(orb_x - half_width, 0.0),
		Vector2(half_width * 2.0, ground_y)
	)
	draw_rect(rect, Color(0.14, 0.75, 0.88, 0.06), true)


func _draw_health_ring(position: Vector2, percent: float, color: Color) -> void:
	var ring_radius: float = maxf(
		_registry.catalog.orb_outer_radius + 7.0,
		ground_core_half_size.y * 0.5 + 8.0
	)
	var end_angle := -PI * 0.5 + TAU * clampf(percent / 100.0, 0.0, 1.0)
	draw_arc(
		position + Vector2(0.0, ground_core_vertical_offset),
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
