class_name DefenderVisual
extends Node2D

@export_node_path("HealthComponent") var health_path: NodePath
@export_range(4.0, 40.0, 1.0) var body_radius: float = 14.0
@export var body_color: Color = Color(0.45, 0.8, 1.0)

@onready var _health: HealthComponent = get_node(health_path)


func _ready() -> void:
	_health.health_changed.connect(_on_health_changed)
	queue_redraw()


func configure(new_radius: float, new_color: Color) -> void:
	body_radius = new_radius
	body_color = new_color
	if is_node_ready():
		queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, body_radius, body_color)
	draw_arc(
		Vector2.ZERO,
		body_radius,
		0.0,
		TAU,
		32,
		Color(0.85, 0.95, 1.0),
		2.0
	)
	_draw_health_segments()


func _draw_health_segments() -> void:
	var segment_width := 8.0
	var segment_height := 4.0
	var gap := 2.0
	var total_width := (
		float(_health.max_health) * segment_width
		+ float(_health.max_health - 1) * gap
	)
	var start_x := -total_width * 0.5
	var y := -body_radius - 10.0

	for index in range(_health.max_health):
		var rect := Rect2(
			Vector2(start_x + float(index) * (segment_width + gap), y),
			Vector2(segment_width, segment_height)
		)
		var fill := (
			Color(0.35, 0.95, 0.48)
			if index < _health.current_health
			else Color(0.18, 0.22, 0.25)
		)
		draw_rect(rect, fill, true)
		draw_rect(rect, Color(0.75, 0.85, 0.9), false, 1.0)


func _on_health_changed(_current_health: int, _max_health: int) -> void:
	queue_redraw()
