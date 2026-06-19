class_name PrototypeWorld
extends Node2D

signal contact_changed(is_active: bool)

@export_node_path("PlatformController") var platform_path: NodePath
@export var ground_y: float = 510.0
@export var orb_x: float = 0.0
@export_range(10.0, 300.0, 1.0) var contact_half_width: float = 72.0
@export var world_min_x: float = -2600.0
@export var world_max_x: float = 2600.0

var contact_active: bool = false

@onready var platform: PlatformController = get_node(platform_path)


func _ready() -> void:
	queue_redraw()


func _process(_delta: float) -> void:
	var new_contact := absf(platform.position.x - orb_x) <= contact_half_width
	if new_contact != contact_active:
		contact_active = new_contact
		contact_changed.emit(contact_active)
	queue_redraw()


func is_contact_active() -> bool:
	return contact_active


func _draw() -> void:
	var ground_rect := Rect2(
		Vector2(world_min_x, ground_y),
		Vector2(world_max_x - world_min_x, 260.0)
	)
	draw_rect(ground_rect, Color(0.09, 0.13, 0.17), true)
	draw_line(
		Vector2(world_min_x, ground_y),
		Vector2(world_max_x, ground_y),
		Color(0.4, 0.5, 0.58),
		4.0
	)

	# Debug contact zone. It will later be replaced by invisible gameplay areas.
	var zone_rect := Rect2(
		Vector2(orb_x - contact_half_width, 0.0),
		Vector2(contact_half_width * 2.0, ground_y)
	)
	draw_rect(zone_rect, Color(0.14, 0.75, 0.88, 0.08), true)
	draw_line(
		Vector2(orb_x - contact_half_width, 0.0),
		Vector2(orb_x - contact_half_width, ground_y),
		Color(0.24, 0.72, 0.84, 0.28),
		2.0
	)
	draw_line(
		Vector2(orb_x + contact_half_width, 0.0),
		Vector2(orb_x + contact_half_width, ground_y),
		Color(0.24, 0.72, 0.84, 0.28),
		2.0
	)

	var orb_position := Vector2(orb_x, ground_y + 20.0)
	draw_circle(orb_position, 38.0, Color(0.08, 0.32, 0.42))
	draw_circle(orb_position, 25.0, Color(0.2, 0.82, 0.96))
	draw_arc(orb_position, 43.0, 0.0, TAU, 64, Color(0.46, 0.94, 1.0), 3.0)

	if contact_active:
		var platform_orb_position := platform.position
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
