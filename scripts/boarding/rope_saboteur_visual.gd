class_name RopeSaboteurVisual
extends Node2D

@export_node_path("HealthComponent") var health_path: NodePath
@export_node_path("RopeSaboteurController") var controller_path: NodePath

var _body_radius: float = 9.0
var _body_color: Color = Color(0.42, 0.65, 0.18)
var _accent_color: Color = Color(0.95, 0.86, 0.2)

@onready var _health: HealthComponent = get_node(health_path)
@onready var _controller: RopeSaboteurController = get_node(controller_path)


func _ready() -> void:
	_health.health_changed.connect(_on_health_changed)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func configure(archetype: BoardingEnemyArchetype) -> void:
	assert(archetype is RopeSaboteurArchetype)
	_body_radius = maxf(4.0, archetype.body_radius)
	_body_color = archetype.body_color
	_accent_color = archetype.accent_color
	if is_node_ready():
		queue_redraw()


func _draw() -> void:
	var progress: float = _controller.get_arming_progress()
	var body_color: Color = _body_color.lerp(
		Color(1.0, 0.18, 0.08),
		progress
	)

	draw_circle(Vector2.ZERO, _body_radius, body_color)
	draw_circle(Vector2(-_body_radius * 0.75, 1.0), _body_radius * 0.55, body_color)
	draw_line(
		Vector2(_body_radius * 0.6, -2.0),
		Vector2(_body_radius + 7.0, -8.0),
		_accent_color,
		2.0
	)
	draw_circle(Vector2(-3.0, -2.0), 1.5, Color(0.05, 0.03, 0.02))
	draw_circle(Vector2(3.0, -2.0), 1.5, Color(0.05, 0.03, 0.02))

	if _controller.is_arming():
		var ring_radius: float = _body_radius + 5.0 + progress * 8.0
		draw_arc(
			Vector2.ZERO,
			ring_radius,
			-PI * 0.5,
			-PI * 0.5 + TAU * progress,
			32,
			Color(1.0, 0.22, 0.08),
			3.0
		)

	_draw_health_bar()


func _draw_health_bar() -> void:
	var width: float = maxf(20.0, _body_radius * 2.0)
	var background := Rect2(
		Vector2(-width * 0.5, -_body_radius - 9.0),
		Vector2(width, 4.0)
	)
	draw_rect(background, Color(0.12, 0.08, 0.04), true)
	var ratio: float = float(_health.current_health) / float(_health.max_health)
	draw_rect(
		Rect2(background.position, Vector2(width * ratio, 4.0)),
		_accent_color,
		true
	)


func _on_health_changed(_current_health: int, _max_health: int) -> void:
	queue_redraw()
