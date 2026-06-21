class_name BoardingEnemyVisual
extends Node2D

@export_node_path("HealthComponent") var health_path: NodePath
@export_node_path("BoardingEnemyController") var controller_path: NodePath

var _body_radius: float = 12.0
var _body_color: Color = Color(0.92, 0.24, 0.2)
var _accent_color: Color = Color(1.0, 0.72, 0.62)
var _archetype_id: StringName = &"basic"

@onready var _health: HealthComponent = get_node(health_path)
@onready var _controller: BoardingEnemyController = get_node(controller_path)


func _ready() -> void:
	_health.health_changed.connect(_on_health_changed)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func configure(archetype: BoardingEnemyArchetype) -> void:
	assert(archetype != null, "BoardingEnemyVisual requires an archetype")
	_body_radius = maxf(4.0, archetype.body_radius)
	_body_color = archetype.body_color
	_accent_color = archetype.accent_color
	_archetype_id = archetype.archetype_id
	if is_node_ready():
		queue_redraw()


func _draw() -> void:
	var body_color: Color = _body_color
	if _controller.get_state() == BoardingEnemyController.State.CLIMBING:
		body_color = body_color.lightened(0.18)
	elif _controller.get_state() == BoardingEnemyController.State.FIGHTING:
		body_color = body_color.darkened(0.12)

	if _archetype_id == &"flyer":
		_draw_flying_body(body_color)
	else:
		draw_circle(Vector2.ZERO, _body_radius, body_color)
		draw_arc(
			Vector2.ZERO,
			_body_radius,
			0.0,
			TAU,
			32,
			_accent_color,
			2.0
		)
	_draw_type_marker()
	_draw_health_bar()


func _draw_flying_body(body_color: Color) -> void:
	draw_circle(Vector2.ZERO, _body_radius, body_color)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-_body_radius, 0.0),
			Vector2(-_body_radius - 14.0, -8.0),
			Vector2(-_body_radius - 8.0, 8.0),
		]),
		_accent_color
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(_body_radius, 0.0),
			Vector2(_body_radius + 14.0, -8.0),
			Vector2(_body_radius + 8.0, 8.0),
		]),
		_accent_color
	)
	draw_arc(Vector2.ZERO, _body_radius, 0.0, TAU, 32, _accent_color, 2.0)


func _draw_type_marker() -> void:
	match _archetype_id:
		&"runner":
			draw_line(
				Vector2(-7.0, 4.0),
				Vector2(7.0, 4.0),
				_accent_color,
				3.0
			)
		&"brute":
			draw_rect(
				Rect2(Vector2(-6.0, -5.0), Vector2(12.0, 10.0)),
				_accent_color,
				false,
				2.0
			)
		&"flyer":
			draw_line(Vector2(-5.0, 4.0), Vector2.ZERO, _accent_color, 2.0)
			draw_line(Vector2.ZERO, Vector2(5.0, 4.0), _accent_color, 2.0)
		_:
			draw_circle(Vector2.ZERO, 3.0, _accent_color)
	draw_circle(Vector2(-4.0, -2.0), 2.0, Color(0.05, 0.03, 0.03))
	draw_circle(Vector2(4.0, -2.0), 2.0, Color(0.05, 0.03, 0.03))


func _draw_health_bar() -> void:
	var width: float = maxf(24.0, _body_radius * 2.0)
	var height: float = 4.0
	var background := Rect2(
		Vector2(-width * 0.5, -_body_radius - 9.0),
		Vector2(width, height)
	)
	draw_rect(background, Color(0.15, 0.08, 0.08), true)
	var ratio: float = float(_health.current_health) / float(_health.max_health)
	var fill := Rect2(background.position, Vector2(width * ratio, height))
	draw_rect(fill, _accent_color, true)


func _on_health_changed(_current_health: int, _max_health: int) -> void:
	queue_redraw()
