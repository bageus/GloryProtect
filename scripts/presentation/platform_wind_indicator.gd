class_name PlatformWindIndicator
extends Node2D

@export_node_path("WindSystem") var wind_system_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath
@export var indicator_offset: Vector2 = Vector2(0.0, -176.0)
@export var arrow_size: Vector2 = Vector2(86.0, 28.0)
@export var brick_size: Vector2 = Vector2(10.0, 6.0)
@export_range(1.0, 12.0, 0.5) var brick_gap: float = 3.0
@export_range(0.0, 1.0, 0.05) var fill_alpha: float = 0.74
@export_range(0.0, 1.0, 0.05) var border_alpha: float = 0.74
@export_range(8, 80, 1) var minimum_z_index: int = 48

var _direction: int = 1
var _strength_level: int = 1

@onready var _wind: WindSystem = get_node(wind_system_path)
@onready var _platform: PlatformController = get_node(platform_path)


func _ready() -> void:
	assert(_wind != null, "PlatformWindIndicator requires WindSystem")
	assert(_platform != null, "PlatformWindIndicator requires PlatformController")
	z_as_relative = true
	z_index = maxi(z_index, minimum_z_index)
	_wind.wind_state_changed.connect(_on_wind_state_changed)
	_apply_wind_state(_wind.direction, _wind.strength_level)
	queue_redraw()


func get_direction() -> int:
	return _direction


func get_strength_text() -> String:
	return ""


func get_label_mouse_filter() -> int:
	return Control.MOUSE_FILTER_IGNORE


func get_indicator_alpha() -> float:
	return fill_alpha


func get_strength_brick_count() -> int:
	return _strength_level


func get_indicator_rect() -> Rect2:
	var rect := Rect2(indicator_offset - arrow_size * 0.5, arrow_size)
	for brick_rect: Rect2 in _build_strength_brick_rects():
		rect = rect.merge(brick_rect)
	return rect


func get_arrow_points_for_tests() -> PackedVector2Array:
	return _build_arrow_points()


func get_strength_brick_rects_for_tests() -> Array[Rect2]:
	return _build_strength_brick_rects()


func _draw() -> void:
	var points: PackedVector2Array = _build_arrow_points()
	var base := Color(0.45, 0.84, 1.0, fill_alpha)
	var border := Color(0.45, 0.84, 1.0, border_alpha)
	draw_colored_polygon(points, base)
	draw_polyline(points, border, 1.6, true)
	_draw_strength_bricks()


func _draw_strength_bricks() -> void:
	var fill := Color(0.45, 0.84, 1.0, fill_alpha * 0.95)
	var border := Color(0.45, 0.84, 1.0, border_alpha)
	for brick_rect: Rect2 in _build_strength_brick_rects():
		draw_rect(brick_rect, fill, true)
		draw_rect(brick_rect, border, false, 1.2)


func _on_wind_state_changed(
	direction: int,
	strength_level: int,
	_base_force: float
) -> void:
	_apply_wind_state(direction, strength_level)


func _apply_wind_state(direction: int, strength_level: int) -> void:
	_direction = 1 if direction >= 0 else -1
	_strength_level = maxi(1, strength_level)
	queue_redraw()


func _build_arrow_points() -> PackedVector2Array:
	var half: Vector2 = arrow_size * 0.5
	var head_width: float = minf(20.0, arrow_size.x * 0.3)
	var tail_indent: float = minf(7.0, arrow_size.y * 0.24)
	var left: float = indicator_offset.x - half.x
	var right: float = indicator_offset.x + half.x
	var top: float = indicator_offset.y - half.y
	var bottom: float = indicator_offset.y + half.y
	var mid_y: float = indicator_offset.y
	var points := PackedVector2Array()
	if _direction > 0:
		points.append(Vector2(left, top + tail_indent))
		points.append(Vector2(right - head_width, top + tail_indent))
		points.append(Vector2(right - head_width, top))
		points.append(Vector2(right, mid_y))
		points.append(Vector2(right - head_width, bottom))
		points.append(Vector2(right - head_width, bottom - tail_indent))
		points.append(Vector2(left, bottom - tail_indent))
	else:
		points.append(Vector2(right, top + tail_indent))
		points.append(Vector2(left + head_width, top + tail_indent))
		points.append(Vector2(left + head_width, top))
		points.append(Vector2(left, mid_y))
		points.append(Vector2(left + head_width, bottom))
		points.append(Vector2(left + head_width, bottom - tail_indent))
		points.append(Vector2(right, bottom - tail_indent))
	return points


func _build_strength_brick_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	var count: int = maxi(1, _strength_level)
	var total_height: float = brick_size.y * float(count) + brick_gap * float(count - 1)
	var arrow_half_width: float = arrow_size.x * 0.5
	var brick_x: float = 0.0
	if _direction > 0:
		brick_x = indicator_offset.x - arrow_half_width - brick_gap - brick_size.x
	else:
		brick_x = indicator_offset.x + arrow_half_width + brick_gap
	var first_y: float = indicator_offset.y - total_height * 0.5
	for index: int in range(count):
		result.append(Rect2(
			Vector2(brick_x, first_y + float(index) * (brick_size.y + brick_gap)),
			brick_size
		))
	return result
