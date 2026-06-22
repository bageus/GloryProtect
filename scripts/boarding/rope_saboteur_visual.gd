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
	var accent: Color = Color(1.0, 0.78, 0.12)
	draw_line(Vector2(5.0, -8.0), Vector2(12.0, -15.0), accent, 2.0)
	draw_circle(Vector2(13.0, -16.0), 2.5 + progress * 2.0, accent)

	if not _behavior.is_arming():
		return
	var ring_color: Color = Color(1.0, 0.2, 0.08)
	var ring_radius: float = 15.0 + progress * 8.0
	draw_arc(
		Vector2.ZERO,
		ring_radius,
		-PI * 0.5,
		-PI * 0.5 + TAU * progress,
		32,
		ring_color,
		3.0
	)
