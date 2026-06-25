class_name StrategicMinimap
extends Control

@export_node_path("ShieldSystem") var shield_system_path: NodePath
@export_node_path("StrategicWaveSystem") var wave_system_path: NodePath
@export_node_path("StrategicWaveDirector") var wave_director_path: NodePath
@export_range(0.1, 4.0, 0.1) var cloud_morph_speed: float = 1.2

var _blink_elapsed: float = 0.0
var _game_flow: GameFlowController

@onready var _shield: ShieldSystem = get_node(shield_system_path)
@onready var _waves: StrategicWaveSystem = get_node(wave_system_path)
@onready var _director: StrategicWaveDirector = get_node(wave_director_path)
@onready var _summary_label: Label = %SummaryLabel
@onready var _next_wave_label: Label = %NextWaveLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scene_root: Node = get_tree().current_scene
	if scene_root != null:
		_game_flow = scene_root.get_node_or_null(
			"GameFlowController"
		) as GameFlowController
	queue_redraw()


func _process(delta: float) -> void:
	if _game_flow == null or _game_flow.is_world_simulation_active():
		_blink_elapsed += maxf(0.0, delta)
	_summary_label.text = "Волна: %d   |   Группы: %d   |   Враги: %d" % [
		_director.get_wave_number(),
		_waves.get_active_group_count(),
		_waves.get_total_enemy_count(),
	]
	_next_wave_label.text = "Следующая: %.1f с   |   размер: %d" % [
		_director.get_wave_remaining(),
		_director.get_current_wave_size(),
	]
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.035, 0.055, 0.95), true)
	draw_line(Vector2(0.0, 27.0), Vector2(size.x, 27.0), Color(0.22, 0.32, 0.46, 0.95), 1.0)
	draw_line(Vector2(0.0, size.y - 1.0), Vector2(size.x, size.y - 1.0), Color(0.28, 0.4, 0.56, 0.95), 2.0)
	var section_count: int = _shield.get_section_count()
	if section_count <= 0:
		return
	var margin_x: float = 8.0
	var lane_top: float = 30.0
	var lane_bottom: float = size.y - 5.0
	var shield_bar_height: float = 14.0
	var shield_bar_y: float = lane_bottom - shield_bar_height
	var lane_width: float = (size.x - margin_x * 2.0) / float(section_count)
	_draw_section_lanes(section_count, margin_x, lane_top, lane_bottom, shield_bar_y, shield_bar_height, lane_width)
	_draw_groups(section_count, margin_x, lane_top, shield_bar_y, lane_width)


func get_visual_kind(enemy_count: int) -> StringName:
	if enemy_count <= 1:
		return &"single"
	if enemy_count == 2:
		return &"pair"
	return &"cloud"


func get_visual_elapsed() -> float:
	return _blink_elapsed


func _draw_section_lanes(
	section_count: int,
	margin_x: float,
	lane_top: float,
	lane_bottom: float,
	shield_bar_y: float,
	shield_bar_height: float,
	lane_width: float
) -> void:
	for section_id: int in range(section_count):
		var lane_x: float = margin_x + float(section_id) * lane_width
		var lane_rect := Rect2(Vector2(lane_x, lane_top), Vector2(lane_width, lane_bottom - lane_top))
		var lane_fill := Color(0.04, 0.055, 0.08, 0.74)
		if section_id % 2 == 1:
			lane_fill = Color(0.055, 0.07, 0.095, 0.74)
		draw_rect(lane_rect, lane_fill, true)
		if section_id > 0:
			draw_line(Vector2(lane_x, lane_top), Vector2(lane_x, lane_bottom), Color(0.18, 0.26, 0.36, 0.8), 1.0)
		var health_percent: float = _shield.get_health_percent(section_id)
		var health_ratio: float = clampf(health_percent / 100.0, 0.0, 1.0)
		var health_color: Color = _get_health_color(section_id)
		var bar_rect := Rect2(Vector2(lane_x + 6.0, shield_bar_y), Vector2(maxf(1.0, lane_width - 12.0), shield_bar_height))
		draw_rect(bar_rect, Color(0.09, 0.11, 0.15, 0.96), true)
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * health_ratio, bar_rect.size.y)), health_color, true)
		draw_rect(bar_rect, Color(0.55, 0.68, 0.82, 0.9), false, 1.0)
		var section_color: Color = _shield.get_section_color(section_id)
		draw_circle(Vector2(bar_rect.position.x + 7.0, bar_rect.get_center().y), 3.0, section_color)
		var text := "%d  %d%%" % [section_id + 1, roundi(health_percent)]
		draw_string(ThemeDB.fallback_font, bar_rect.position + Vector2(0.0, 11.0), text, HORIZONTAL_ALIGNMENT_CENTER, bar_rect.size.x, 10, Color.WHITE)


func _draw_groups(
	section_count: int,
	margin_x: float,
	lane_top: float,
	shield_bar_y: float,
	lane_width: float
) -> void:
	var maximum_lane_offset: float = maxf(0.001, _waves.balance.maximum_lane_offset)
	var near_y: float = shield_bar_y - 7.0
	var far_y: float = lane_top + 7.0
	for snapshot: StrategicGroupSnapshot in _waves.get_group_snapshots():
		var section_id: int = clampi(snapshot.section_id, 0, section_count - 1)
		var lane_center_x: float = margin_x + (float(section_id) + 0.5) * lane_width
		var offset_ratio: float = clampf(snapshot.lane_offset / maximum_lane_offset, -1.0, 1.0)
		var marker_position := Vector2(
			lane_center_x + offset_ratio * lane_width * 0.2,
			lerpf(near_y, far_y, clampf(snapshot.map_distance, 0.0, 1.0))
		)
		_draw_group_marker(snapshot, marker_position)


func _draw_group_marker(snapshot: StrategicGroupSnapshot, position: Vector2) -> void:
	var color := Color(0.88, 0.18, 0.18, 0.94)
	if snapshot.is_impacting:
		var pulse: float = 0.72 + sin(_blink_elapsed * 8.0) * 0.2
		color = Color(1.0, 0.32, 0.08, pulse)
		draw_circle(position, 13.0, Color(1.0, 0.12, 0.04, 0.16))
	match get_visual_kind(snapshot.enemy_count):
		&"single":
			_draw_enemy_figure(position, 1.0, color)
		&"pair":
			_draw_enemy_figure(position + Vector2(-4.0, 1.0), 0.9, color)
			_draw_enemy_figure(position + Vector2(4.0, -1.0), 0.9, color.darkened(0.08))
		_:
			_draw_enemy_cloud(snapshot, position, color)


func _draw_enemy_figure(position: Vector2, scale: float, color: Color) -> void:
	draw_circle(position + Vector2(0.0, -2.0) * scale, 2.5 * scale, color)
	var body := PackedVector2Array([
		position + Vector2(-3.2, 0.0) * scale,
		position + Vector2(3.2, 0.0) * scale,
		position + Vector2(2.0, 4.5) * scale,
		position + Vector2(-2.0, 4.5) * scale,
	])
	draw_colored_polygon(body, color.darkened(0.08))
	draw_line(position + Vector2(-1.5, 4.0) * scale, position + Vector2(-2.5, 7.0) * scale, Color(0.16, 0.02, 0.03, 1.0), 1.2)
	draw_line(position + Vector2(1.5, 4.0) * scale, position + Vector2(2.5, 7.0) * scale, Color(0.16, 0.02, 0.03, 1.0), 1.2)


func _draw_enemy_cloud(snapshot: StrategicGroupSnapshot, position: Vector2, color: Color) -> void:
	var count_scale: float = sqrt(float(snapshot.enemy_count))
	var radius_x: float = clampf(5.0 + count_scale * 1.8, 8.0, 17.0)
	var radius_y: float = clampf(4.0 + count_scale * 1.2, 6.0, 12.0)
	var points := PackedVector2Array()
	var point_count: int = 14
	for index: int in range(point_count):
		var angle: float = TAU * float(index) / float(point_count)
		var phase: float = _blink_elapsed * cloud_morph_speed + float(snapshot.group_id) * 1.37 + float(index) * 2.11
		var wobble: float = 1.0 + sin(phase) * 0.12
		points.append(position + Vector2(cos(angle) * radius_x * wobble, sin(angle) * radius_y * (2.0 - wobble)))
	draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(0.12, 0.02, 0.02, 0.95), 1.2, true)
	var visible_specks: int = mini(snapshot.enemy_count, 6)
	for index: int in range(visible_specks):
		var seed: float = float(snapshot.group_id * 17 + index * 11)
		var offset := Vector2(sin(seed * 1.7) * radius_x * 0.55, cos(seed * 2.3) * radius_y * 0.45)
		draw_circle(position + offset, 1.3, Color(0.2, 0.02, 0.03, 0.9))


func _get_health_color(section_id: int) -> Color:
	var percent: float = _shield.get_health_percent(section_id)
	if percent > _shield.balance.indicator_threshold_percent:
		return Color(0.22, 0.88, 0.36)
	if percent > _shield.balance.critical_threshold_percent:
		return Color(1.0, 0.67, 0.12)
	var pulse: float = 0.55 + sin(_blink_elapsed * 7.0) * 0.25
	return Color(1.0, 0.1, 0.08, pulse)
