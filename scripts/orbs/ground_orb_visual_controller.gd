class_name GroundOrbVisualController
extends Node2D

@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("GroundOrbRegistry") var registry_path: NodePath
@export_node_path("OrbContactSystem") var contact_system_path: NodePath
@export_node_path("ShieldSystem") var shield_system_path: NodePath
@export var platform_balance: PlatformBalance
@export var show_contact_zones: bool = false

@onready var _platform: PlatformController = get_node(platform_path)
@onready var _registry: GroundOrbRegistry = get_node(registry_path)
@onready var _contact: OrbContactSystem = get_node(contact_system_path)
@onready var _shield: ShieldSystem = get_node(shield_system_path)


func _ready() -> void:
	assert(platform_balance != null, "GroundOrbVisualController requires PlatformBalance")
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	_draw_ground()
	for orb_id in range(_registry.get_orb_count()):
		_draw_orb(orb_id)
	_draw_active_contact()


func _draw_ground() -> void:
	var ground_y := _registry.catalog.ground_y
	var ground_rect := Rect2(
		Vector2(platform_balance.world_min_x, ground_y),
		Vector2(
			platform_balance.world_max_x - platform_balance.world_min_x,
			_registry.catalog.ground_depth
		)
	)
	draw_rect(ground_rect, Color(0.09, 0.13, 0.17), true)
	draw_line(
		Vector2(platform_balance.world_min_x, ground_y),
		Vector2(platform_balance.world_max_x, ground_y),
		Color(0.4, 0.5, 0.58),
		4.0
	)


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

	var core_color := section_color * brightness
	core_color.a = 1.0
	var outer_color := section_color.darkened(0.55)
	outer_color.a = 1.0

	if show_contact_zones:
		_draw_contact_zone(orb_id)

	draw_circle(position, _registry.catalog.orb_outer_radius - 5.0, outer_color)
	draw_circle(position, _registry.catalog.orb_core_radius, core_color)
	draw_arc(
		position,
		_registry.catalog.orb_outer_radius,
		0.0,
		TAU,
		64,
		section_color,
		3.0
	)
	_draw_health_ring(position, percent, section_color)


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
	var end_angle := -PI * 0.5 + TAU * clampf(percent / 100.0, 0.0, 1.0)
	draw_arc(
		position,
		_registry.catalog.orb_outer_radius + 7.0,
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
