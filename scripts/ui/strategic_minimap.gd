class_name StrategicMinimap
extends Control

@export_node_path("ShieldSystem") var shield_system_path: NodePath
@export_node_path("StrategicWaveSystem") var wave_system_path: NodePath
@export_node_path("StrategicWaveDirector") var wave_director_path: NodePath

var _blink_elapsed: float = 0.0

@onready var _shield: ShieldSystem = get_node(shield_system_path)
@onready var _waves: StrategicWaveSystem = get_node(wave_system_path)
@onready var _director: StrategicWaveDirector = get_node(wave_director_path)
@onready var _summary_label: Label = %SummaryLabel
@onready var _next_wave_label: Label = %NextWaveLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(delta: float) -> void:
	_blink_elapsed += maxf(0.0, delta)
	_summary_label.text = "Группы: %d | враги: %d | волна: %d" % [
		_waves.get_active_group_count(),
		_waves.get_total_enemy_count(),
		_director.get_wave_number(),
	]
	_next_wave_label.text = "Следующая волна: %.1f с | размер: %d" % [
		_director.get_wave_remaining(),
		_director.get_current_wave_size(),
	]
	queue_redraw()


func _draw() -> void:
	var map_rect := Rect2(Vector2.ZERO, size)
	draw_rect(map_rect, Color(0.025, 0.035, 0.055, 0.94), true)
	draw_rect(map_rect, Color(0.25, 0.34, 0.46, 0.9), false, 2.0)

	var center := Vector2(size.x * 0.5, size.y * 0.54)
	var shield_radius: float = minf(size.x, size.y) * 0.22
	var spawn_radius: float = minf(size.x, size.y) * 0.42
	_draw_shield(center, shield_radius)
	_draw_groups(center, shield_radius, spawn_radius)


func _draw_shield(center: Vector2, radius: float) -> void:
	var section_count: int = _shield.get_section_count()
	if section_count <= 0:
		return
	var segment_angle: float = TAU / float(section_count)
	for section_id: int in range(section_count):
		var angle: float = _get_section_angle(section_id, section_count)
		var color: Color = _get_health_color(section_id)
		draw_arc(
			center,
			radius,
			angle - segment_angle * 0.38,
			angle + segment_angle * 0.38,
			20,
			color,
			12.0,
			true
		)
		var marker_position: Vector2 = center + Vector2.from_angle(angle) * radius
		draw_circle(marker_position, 5.0, _shield.get_section_color(section_id))
		var percent_text: String = "%d" % roundi(
			_shield.get_health_percent(section_id)
		)
		draw_string(
			ThemeDB.fallback_font,
			marker_position + Vector2(-12.0, -10.0),
			percent_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			24.0,
			11,
			Color.WHITE
		)


func _draw_groups(center: Vector2, shield_radius: float, spawn_radius: float) -> void:
	var section_count: int = _shield.get_section_count()
	for snapshot: StrategicGroupSnapshot in _waves.get_group_snapshots():
		if snapshot.section_id < 0 or snapshot.section_id >= section_count:
			continue
		var target_angle: float = _get_section_angle(
			snapshot.section_id,
			section_count
		)
		var start_angle: float = target_angle + snapshot.lane_offset
		var start_position: Vector2 = (
			center + Vector2.from_angle(start_angle) * spawn_radius
		)
		var target_position: Vector2 = (
			center + Vector2.from_angle(target_angle) * shield_radius
		)
		var position: Vector2 = start_position.lerp(
			target_position,
			clampf(snapshot.progress, 0.0, 1.0)
		)
		var mass_radius: float = clampf(
			6.0 + sqrt(float(snapshot.enemy_count)) * 2.2,
			7.0,
			24.0
		)
		var mass_color := Color(0.88, 0.18, 0.18, 0.88)
		if snapshot.is_impacting:
			mass_color = Color(1.0, 0.34, 0.12, 0.92)
		draw_circle(position, mass_radius, mass_color)
		draw_arc(position, mass_radius, 0.0, TAU, 20, Color(0.12, 0.02, 0.02), 2.0)
		draw_string(
			ThemeDB.fallback_font,
			position + Vector2(-12.0, 4.0),
			str(snapshot.enemy_count),
			HORIZONTAL_ALIGNMENT_CENTER,
			24.0,
			12,
			Color.WHITE
		)


func _get_section_angle(section_id: int, section_count: int) -> float:
	return -PI * 0.5 + TAU * float(section_id) / float(section_count)


func _get_health_color(section_id: int) -> Color:
	var percent: float = _shield.get_health_percent(section_id)
	if percent > 50.0:
		return Color(0.22, 0.88, 0.36)
	if percent > 25.0:
		return Color(1.0, 0.67, 0.12)
	var pulse: float = 0.55 + sin(_blink_elapsed * 7.0) * 0.25
	return Color(1.0, 0.1, 0.08, pulse)
