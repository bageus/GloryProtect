class_name BoardingEnemyVisual
extends Node2D

@export_node_path("HealthComponent") var health_path: NodePath
@export_node_path("BoardingEnemyController") var controller_path: NodePath

var _body_radius: float = 12.0

@onready var _health: HealthComponent = get_node(health_path)
@onready var _controller: BoardingEnemyController = get_node(controller_path)


func _ready() -> void:
	_health.health_changed.connect(_on_health_changed)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func configure(body_radius: float) -> void:
	_body_radius = maxf(4.0, body_radius)
	if is_node_ready():
		queue_redraw()


func _draw() -> void:
	var body_color := Color(0.92, 0.24, 0.2)
	if _controller.get_state() == BoardingEnemyController.State.CLIMBING:
		body_color = Color(1.0, 0.48, 0.18)
	elif _controller.get_state() == BoardingEnemyController.State.FIGHTING:
		body_color = Color(1.0, 0.12, 0.12)

	draw_circle(Vector2.ZERO, _body_radius, body_color)
	draw_arc(
		Vector2.ZERO,
		_body_radius,
		0.0,
		TAU,
		32,
		Color(1.0, 0.72, 0.62),
		2.0
	)
	draw_circle(Vector2(-4.0, -2.0), 2.0, Color(0.05, 0.03, 0.03))
	draw_circle(Vector2(4.0, -2.0), 2.0, Color(0.05, 0.03, 0.03))
	_draw_health_bar()


func _draw_health_bar() -> void:
	var width: float = 24.0
	var height: float = 4.0
	var background := Rect2(
		Vector2(-width * 0.5, -_body_radius - 9.0),
		Vector2(width, height)
	)
	draw_rect(background, Color(0.15, 0.08, 0.08), true)
	var ratio: float = float(_health.current_health) / float(_health.max_health)
	var fill := Rect2(background.position, Vector2(width * ratio, height))
	draw_rect(fill, Color(1.0, 0.32, 0.25), true)


func _on_health_changed(_current_health: int, _max_health: int) -> void:
	queue_redraw()
