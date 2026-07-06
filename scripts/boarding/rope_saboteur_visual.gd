class_name RopeSaboteurVisual
extends Node2D

@export_node_path("RopeSaboteurBehavior") var behavior_path := NodePath("..")

@onready var _behavior: RopeSaboteurBehavior = get_node(behavior_path)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _behavior == null or not _behavior.active:
		return

	var progress: float = _behavior.get_arming_progress()
	var accent: Color = Color(1.0, 0.92, 0.18)
	var hot_core: Color = Color(1.0, 0.96, 0.55)
	draw_line(Vector2(5.0, -8.0), Vector2(12.0, -15.0), accent, 2.5)
	draw_circle(Vector2(13.0, -16.0), 3.0 + progress * 2.5, accent)
	draw_circle(Vector2(13.0, -16.0), 1.5 + progress * 1.2, hot_core)

	if not _behavior.is_arming():
		return
	var ring_color: Color = Color(1.0, 0.35, 0.04)
	var flash_color: Color = Color(1.0, 0.9, 0.18, 0.75)
	var ring_radius: float = 13.0 + progress * 10.0
	draw_circle(Vector2.ZERO, 5.0 + progress * 8.0, Color(1.0, 0.26, 0.02, 0.35))
	draw_arc(
		Vector2.ZERO,
		ring_radius,
		-PI * 0.5,
		-PI * 0.5 + TAU * progress,
		32,
		ring_color,
		4.0
	)
	draw_arc(
		Vector2.ZERO,
		ring_radius + 4.0,
		-PI * 0.5,
		-PI * 0.5 + TAU * progress,
		32,
		flash_color,
		2.0
	)
