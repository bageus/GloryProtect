class_name DefenderVisual
extends Node2D

@export_node_path("HealthComponent") var health_path: NodePath
@export_node_path("StatusEffectComponent") var status_effects_path: NodePath
@export_range(4.0, 40.0, 1.0) var body_radius: float = 14.0
@export var body_color: Color = Color(0.45, 0.8, 1.0)

var _selected: bool = false
var _poisoned: bool = false
var _poison_stacks: int = 0

@onready var _health: HealthComponent = get_node(health_path)
@onready var _status_effects: StatusEffectComponent = get_node(status_effects_path)


func _ready() -> void:
	_health.health_changed.connect(_on_health_changed)
	_status_effects.poison_changed.connect(_on_poison_changed)
	queue_redraw()


func configure(new_radius: float, new_color: Color) -> void:
	body_radius = new_radius
	body_color = new_color
	if is_node_ready():
		queue_redraw()


func set_selected(is_selected: bool) -> void:
	if _selected == is_selected:
		return
	_selected = is_selected
	queue_redraw()


func is_selected() -> bool:
	return _selected


func _draw() -> void:
	if _selected:
		draw_arc(
			Vector2.ZERO,
			body_radius + 6.0,
			0.0,
			TAU,
			40,
			Color(1.0, 0.84, 0.25),
			3.0
		)
		draw_circle(
			Vector2(0.0, body_radius + 11.0),
			3.5,
			Color(1.0, 0.84, 0.25)
		)
	var active_body_color: Color = body_color
	if _poisoned:
		active_body_color = body_color.lerp(Color(0.48, 0.9, 0.25), 0.45)
	draw_circle(Vector2.ZERO, body_radius, active_body_color)
	draw_arc(
		Vector2.ZERO,
		body_radius,
		0.0,
		TAU,
		32,
		Color(0.85, 0.95, 1.0),
		2.0
	)
	if _poisoned:
		_draw_poison_indicator()
	_draw_health_segments()


func _draw_poison_indicator() -> void:
	var marker_position := Vector2(body_radius + 7.0, -body_radius - 4.0)
	draw_circle(marker_position, 5.0, Color(0.52, 0.95, 0.25))
	for index: int in range(_poison_stacks):
		draw_circle(
			marker_position + Vector2(float(index - _poison_stacks + 1) * 3.0, 8.0),
			1.5,
			Color(0.76, 1.0, 0.5)
		)


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

	for index: int in range(_health.max_health):
		var rect := Rect2(
			Vector2(start_x + float(index) * (segment_width + gap), y),
			Vector2(segment_width, segment_height)
		)
		var fill := Color(0.18, 0.22, 0.25)
		if index < _health.current_health:
			fill = Color(0.35, 0.95, 0.48)
		draw_rect(rect, fill, true)
		draw_rect(rect, Color(0.75, 0.85, 0.9), false, 1.0)


func _on_health_changed(_current_health: int, _max_health: int) -> void:
	queue_redraw()


func _on_poison_changed(active: bool, stacks: int, _remaining: float) -> void:
	_poisoned = active
	_poison_stacks = stacks
	queue_redraw()
