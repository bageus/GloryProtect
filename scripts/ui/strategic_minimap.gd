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
	var panel_rect := Rect2(Vector2.ZERO, size)
	draw_rect(panel_rect, Color(0.025, 0.035, 0.055, 0.95), true)
	draw_line(
		Vector2(0.0, 36.0),
		Vector2(size.x, 36.0),
		Color(0.22, 0.32, 0.46, 0.95),
		2.0
	)
	draw_line(
		Vector2(0.0, size.y - 1.0),
		Vector2(size.x, size.y - 1.0),
		Color(0.28, 0.4, 0.56, 0.95),
		2.0
	)

	var section_count: int = _shield.get_section_count()
	if section_count <= 0:
		return

	var margin_x: float = 12.0
	var lane_top: float = 43.0
	var lane_bottom: float = size.y - 10.0
	var shield_bar_height: float = 18.0
	var shield_bar_y: float = lane_bottom - shield_bar_height
	var lane_width: float = (size.x - margin_x * 2.0) / float(section_count)

	_draw_section_lanes(
		section_count,
		margin_x,
		lane_top,
		lane_bottom,
		shield_bar_y,
		shield_bar_height,
		lane_width
	)
	_draw_groups(
		section_count,
		margin_x,
		lane_top,
		shield_bar_y,
		lane_width
	)


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
		var lane_rect := Rect2(
			Vector2(lane_x, lane_top),
			Vector2(lane_width, lane_bottom - lane_top)
		)
		var lane_fill := Color(0.04, 0.055, 0.08, 0.74)
		if section_id % 2 == 1:
			lane_fill = Color(0.055, 0.07, 0.095, 0.74)
		draw_rect(lane_rect, lane_fill, true)

		if section_id > 0:
			draw_line(
				Vector2(lane_x, lane_top),
				Vector2(lane_x, lane_bottom),
				Color(0.18, 0.26, 0.36, 0.8),
				1.0
			)

		var health_percent: float = _shield.get_health_percent(section_id)
		var health_ratio: float = clampf(health_percent / 100.0, 0.0, 1.0)
		var health_color: Color = _get_health_color(section_id)
		var bar_rect := Rect2(
			Vector2(lane_x + 10.0, shield_bar_y),
			Vector2(maxf(1.0, lane_width - 20.0), shield_bar_height)
		)
		draw_rect(bar_rect, Color(0.09, 0.11, 0.15, 0.96), true)
		draw_rect(
			Rect2(
				bar_rect.position,
				Vector2(bar_rect.size.x * health_ratio, bar_rect.size.y)
			),
			health_color,
			true
		)
		draw_rect(
			bar_rect,
			Color(0.55, 0.68, 0.82, 0.9),
			false,
			1.0
		)

		var section_color: Color = _shield.get_section_color(section_id)
		draw_circle(
			Vector2(bar_rect.position.x + 9.0, bar_rect.get_center().y),
			4.0,
			section_color
		)

		var text: String = "%d   %d%%" % [
			section_id + 1,
			roundi(health_percent),
		]
		draw_string(
			ThemeDB.fallback_font,
			bar_rect.position + Vector2(0.0, 13.0),
			text,
			HORIZONTAL_ALIGNMENT_CENTER,
			bar_rect.size.x,
			12,
			Color.WHITE
		)


func _draw_groups(
	section_count: int,
	margin_x: float,
	lane_top: float,
	shield_bar_y: float,
	lane_width: float
) -> void:
	var maximum_lane_offset: float = maxf(
		0.001,
		_waves.balance.maximum_lane_offset
	)
	var near_y: float = shield_bar_y - 12.0
	var far_y: float = lane_top + 14.0

	for snapshot: StrategicGroupSnapshot in _waves.get_group_snapshots():
		var section_id: int = mini(
			section_count - 1,
			maxi(0, snapshot.section_id)
		)
		var lane_center_x: float = (
			margin_x
			+ (float(section_id) + 0.5) * lane_width
		)
		var offset_ratio: float = clampf(
			snapshot.lane_offset / maximum_lane_offset,
			-1.0,
			1.0
		)
		var position := Vector2(
			lane_center_x + offset_ratio * lane_width * 0.24,
			lerpf(
				near_y,
				far_y,
				clampf(snapshot.map_distance, 0.0, 1.0)
			)
		)
		var target_position := Vector2(lane_center_x, shield_bar_y)
		draw_line(
			position,
			target_position,
			Color(0.62, 0.12, 0.12, 0.24),
			1.0
		)

		var mass_radius: float = clampf(
			6.0 + sqrt(float(snapshot.enemy_count)) * 1.7,
			7.0,
			18.0
		)
		var mass_color := Color(0.88, 0.18, 0.18, 0.92)
		if snapshot.is_impacting:
			var pulse: float = 0.72 + sin(_blink_elapsed * 8.0) * 0.2
			mass_color = Color(1.0, 0.32, 0.08, pulse)
			draw_circle(
				position,
				mass_radius + 5.0,
				Color(1.0, 0.12, 0.04, 0.18)
			)
		draw_circle(position, mass_radius, mass_color)
		draw_arc(
			position,
			mass_radius,
			0.0,
			TAU,
			20,
			Color(0.12, 0.02, 0.02),
			2.0
		)
		draw_string(
			ThemeDB.fallback_font,
			position + Vector2(-mass_radius, 4.0),
			str(snapshot.enemy_count),
			HORIZONTAL_ALIGNMENT_CENTER,
			mass_radius * 2.0,
			12,
			Color.WHITE
		)


func _get_health_color(section_id: int) -> Color:
	var percent: float = _shield.get_health_percent(section_id)
	if percent > _shield.balance.indicator_threshold_percent:
		return Color(0.22, 0.88, 0.36)
	if percent > _shield.balance.critical_threshold_percent:
		return Color(1.0, 0.67, 0.12)
	var pulse: float = 0.55 + sin(_blink_elapsed * 7.0) * 0.25
	return Color(1.0, 0.1, 0.08, pulse)
