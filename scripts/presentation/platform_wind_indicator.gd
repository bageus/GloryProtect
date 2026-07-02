class_name PlatformWindIndicator
extends Node2D

@export_node_path("WindSystem") var wind_system_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath
@export var indicator_offset: Vector2 = Vector2(0.0, -104.0)
@export var arrow_size: Vector2 = Vector2(96.0, 36.0)
@export_range(0.0, 1.0, 0.05) var fill_alpha: float = 0.42
@export_range(0.0, 1.0, 0.05) var border_alpha: float = 0.76
@export_range(8, 40, 1) var strength_font_size: int = 20

var _direction: int = 1
var _strength_level: int = 1
var _strength_label: Label

@onready var _wind: WindSystem = get_node(wind_system_path)
@onready var _platform: PlatformController = get_node(platform_path)


func _ready() -> void:
	assert(_wind != null, "PlatformWindIndicator requires WindSystem")
	assert(_platform != null, "PlatformWindIndicator requires PlatformController")
	z_as_relative = true
	_build_strength_label()
	_wind.wind_state_changed.connect(_on_wind_state_changed)
	_apply_wind_state(_wind.direction, _wind.strength_level)
	queue_redraw()


func get_direction() -> int:
	return _direction


func get_strength_text() -> String:
	return "" if _strength_label == null else _strength_label.text


func get_label_mouse_filter() -> int:
	return -1 if _strength_label == null else _strength_label.mouse_filter


func get_indicator_alpha() -> float:
	return fill_alpha


func get_indicator_rect() -> Rect2:
	return Rect2(indicator_offset - arrow_size * 0.5, arrow_size)


func get_arrow_points_for_tests() -> PackedVector2Array:
	return _build_arrow_points()


func _draw() -> void:
	var points: PackedVector2Array = _build_arrow_points()
	var fill := Color(0.28, 0.72, 1.0, fill_alpha)
	var border := Color(0.78, 0.92, 1.0, border_alpha)
	draw_colored_polygon(points, fill)
	draw_polyline(points, border, 2.0, true)


func _build_strength_label() -> void:
	_strength_label = Label.new()
	_strength_label.name = "StrengthLabel"
	_strength_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strength_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_strength_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_strength_label.add_theme_font_size_override("font_size", strength_font_size)
	_strength_label.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0, 0.96))
	_strength_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.07, 0.82))
	_strength_label.add_theme_constant_override("shadow_offset_x", 1)
	_strength_label.add_theme_constant_override("shadow_offset_y", 1)
	_strength_label.size = Vector2(52.0, 30.0)
	_strength_label.position = indicator_offset - _strength_label.size * 0.5
	add_child(_strength_label)


func _on_wind_state_changed(
	direction: int,
	strength_level: int,
	_base_force: float
) -> void:
	_apply_wind_state(direction, strength_level)


func _apply_wind_state(direction: int, strength_level: int) -> void:
	_direction = 1 if direction >= 0 else -1
	_strength_level = maxi(1, strength_level)
	if _strength_label != null:
		_strength_label.text = str(_strength_level)
		_strength_label.position = indicator_offset - _strength_label.size * 0.5
	queue_redraw()


func _build_arrow_points() -> PackedVector2Array:
	var half: Vector2 = arrow_size * 0.5
	var head_width: float = minf(24.0, arrow_size.x * 0.34)
	var tail_indent: float = minf(10.0, arrow_size.y * 0.28)
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
