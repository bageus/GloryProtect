class_name StrategicMinimap
extends Control

const MAP_WIDTH_RATIO: float = 5.0 / 6.0
const SHIELD_BAR_HEIGHT: float = 14.0
const CAPACITY_TICK_HEIGHT: float = 4.0
const CORE_BULGE_RADIUS: float = 5.2
const MAP_BOTTOM_RESERVED: float = 20.0

@export_node_path("ShieldSystem") var shield_system_path: NodePath
@export_node_path("StrategicWaveSystem") var wave_system_path: NodePath
@export_node_path("StrategicWaveDirector") var wave_director_path: NodePath
@export_node_path("RunEconomy") var run_economy_path: NodePath = NodePath("../../RunEconomy")
@export_node_path("UpgradeSystem") var upgrade_system_path: NodePath = NodePath("../../UpgradeSystem")
@export_range(0.1, 4.0, 0.1) var cloud_morph_speed: float = 1.2
@export_range(0.4, 2.0, 0.05) var energy_wave_duration: float = 0.9
@export_range(0.35, 1.2, 0.05) var energy_wave_radius_scale: float = 0.82

var _blink_elapsed: float = 0.0
var _energy_waves: Array[Dictionary] = []
var _game_flow: GameFlowController

@onready var _shield: ShieldSystem = get_node(shield_system_path)
@onready var _waves: StrategicWaveSystem = get_node(wave_system_path)
@onready var _director: StrategicWaveDirector = get_node(wave_director_path)
@onready var _economy: RunEconomy = get_node(run_economy_path)
@onready var _upgrades: UpgradeSystem = get_node(upgrade_system_path)
@onready var _summary_label: Label = %SummaryLabel
@onready var _coins_label: Label = %CoinsLabel
@onready var _upgrade_level_label: Label = %UpgradeLevelLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scene_root: Node = _resolve_scene_root()
	if scene_root != null:
		_game_flow = scene_root.get_node_or_null(
			"GameFlowController"
		) as GameFlowController
	if not _waves.strategic_enemy_impacted.is_connected(
		_on_strategic_enemy_impacted
	):
		_waves.strategic_enemy_impacted.connect(_on_strategic_enemy_impacted)
	queue_redraw()


func _process(delta: float) -> void:
	var simulation_active: bool = (
		_game_flow == null or _game_flow.is_world_simulation_active()
	)
	if simulation_active:
		var safe_delta: float = maxf(0.0, delta)
		_blink_elapsed += safe_delta
		_update_energy_waves(safe_delta)
	_summary_label.text = "Волна: %d" % _director.get_wave_number()
	_coins_label.text = "Монеты: %d" % _economy.get_coins()
	_upgrade_level_label.text = "Уровень: %d" % (
		_upgrades.get_current_offer_number()
	)
	queue_redraw()


func _draw() -> void:
	var map_width: float = _get_map_width()
	draw_rect(
		Rect2(Vector2.ZERO, Vector2(map_width, size.y)),
		Color(0.025, 0.035, 0.055, 0.95),
		true
	)
	draw_line(Vector2(0.0, 27.0), Vector2(map_width, 27.0), Color(0.22, 0.32, 0.46, 0.95), 1.0)
	draw_line(Vector2(0.0, size.y - 1.0), Vector2(map_width, size.y - 1.0), Color(0.28, 0.4, 0.56, 0.95), 2.0)
	draw_line(Vector2(map_width, 0.0), Vector2(map_width, size.y), Color(0.28, 0.4, 0.56, 0.95), 2.0)
	var section_count: int = _shield.get_section_count()
	if section_count <= 0:
		return
	var margin_x: float = 8.0
	var lane_top: float = 30.0
	var lane_bottom: float = _get_lane_bottom()
	var shield_bar_y: float = lane_bottom - SHIELD_BAR_HEIGHT
	var lane_width: float = (map_width - margin_x * 2.0) / float(section_count)
	_draw_section_lanes(section_count, margin_x, lane_top, lane_bottom, shield_bar_y, lane_width)
	_draw_energy_waves(section_count, margin_x, lane_top, shield_bar_y, lane_width)
	_draw_groups(section_count, margin_x, lane_top, shield_bar_y, lane_width)


func get_visual_kind(enemy_count: int) -> StringName:
	if enemy_count <= 1:
		return &"single"
	if enemy_count == 2:
		return &"pair"
	return &"cloud"


func get_visual_elapsed() -> float:
	return _blink_elapsed


func get_map_width() -> float:
	return _get_map_width()


func get_core_marker_count() -> int:
	return _shield.get_section_count()


func get_core_marker_position(section_id: int) -> Vector2:
	var section_count: int = _shield.get_section_count()
	if section_count <= 0 or not _shield.is_valid_section(section_id):
		return Vector2.ZERO
	var margin_x: float = 8.0
	var lane_bottom: float = _get_lane_bottom()
	var shield_bar_y: float = lane_bottom - SHIELD_BAR_HEIGHT
	var lane_width: float = (_get_map_width() - margin_x * 2.0) / float(section_count)
	return _get_core_marker_position(section_id, margin_x, shield_bar_y, lane_width)


func get_section_health_ratio_for_tests(section_id: int) -> float:
	return _get_section_health_ratio(section_id)


func get_section_health_text_for_tests(section_id: int) -> String:
	return _get_section_health_text(section_id)


func get_capacity_percent_for_tests() -> int:
	return _get_capacity_percent()


func get_active_energy_wave_count() -> int:
	return _energy_waves.size()


func has_energy_wave_for_section(section_id: int) -> bool:
	for wave: Dictionary in _energy_waves:
		if int(wave["section"]) == section_id:
			return true
	return false


func debug_emit_energy_wave(section_id: int) -> void:
	_on_strategic_enemy_impacted(section_id, 0.0)


func _get_map_width() -> float:
	return size.x * MAP_WIDTH_RATIO


func _get_lane_bottom() -> float:
	return maxf(44.0, size.y - MAP_BOTTOM_RESERVED)


func _resolve_scene_root() -> Node:
	var current: Node = get_tree().current_scene
	if current != null and current.is_ancestor_of(self):
		return current
	current = self
	while current.get_parent() != null and current.get_parent() != get_tree().root:
		current = current.get_parent()
	return current


func _draw_section_lanes(
	section_count: int,
	margin_x: float,
	lane_top: float,
	lane_bottom: float,
	shield_bar_y: float,
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
		var health_ratio: float = _get_section_health_ratio(section_id)
		var health_color: Color = _get_health_color(section_id)
		var bar_rect := Rect2(
			Vector2(lane_x + 6.0, shield_bar_y),
			Vector2(maxf(1.0, lane_width - 12.0), SHIELD_BAR_HEIGHT)
		)
		draw_rect(bar_rect, Color(0.09, 0.11, 0.15, 0.96), true)
		_draw_capacity_bonus_marks(bar_rect)
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * health_ratio, bar_rect.size.y)), health_color, true)
		_draw_core_bulge(section_id, bar_rect, health_color)
		draw_rect(bar_rect, Color(0.55, 0.68, 0.82, 0.9), false, 1.0)
		var text := _get_section_health_text(section_id)
		draw_string(
			ThemeDB.fallback_font,
			bar_rect.position + Vector2(2.0, 11.0),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			bar_rect.size.x,
			9,
			Color.WHITE
		)


func _draw_capacity_bonus_marks(bar_rect: Rect2) -> void:
	var capacity_multiplier: float = _get_capacity_multiplier()
	if capacity_multiplier <= 1.001:
		return
	var base_end_x: float = bar_rect.position.x + bar_rect.size.x / capacity_multiplier
	var extra_rect := Rect2(
		Vector2(base_end_x, bar_rect.position.y),
		Vector2(bar_rect.end.x - base_end_x, bar_rect.size.y)
	)
	draw_rect(extra_rect, Color(0.26, 0.58, 0.96, 0.2), true)
	draw_line(
		Vector2(base_end_x, bar_rect.position.y),
		Vector2(base_end_x, bar_rect.end.y),
		Color(0.75, 0.96, 1.0, 0.78),
		1.3
	)
	var bonus_ticks: int = maxi(1, roundi((capacity_multiplier - 1.0) * 10.0))
	for tick_index: int in range(bonus_ticks):
		var tick_x: float = lerpf(
			base_end_x,
			bar_rect.end.x,
			float(tick_index + 1) / float(bonus_ticks)
		)
		draw_line(
			Vector2(tick_x, bar_rect.position.y - CAPACITY_TICK_HEIGHT),
			Vector2(tick_x, bar_rect.position.y + 2.0),
			Color(0.86, 0.98, 1.0, 0.9),
			1.2
		)


func _draw_core_bulge(section_id: int, bar_rect: Rect2, health_color: Color) -> void:
	var center: Vector2 = bar_rect.get_center()
	var section_color: Color = _shield.get_section_color(section_id)
	var pulse: float = 0.88 + sin(_blink_elapsed * 2.4 + float(section_id)) * 0.07
	var radius: float = CORE_BULGE_RADIUS * pulse
	var cap_rect := Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
	draw_circle(center, radius + 2.0, Color(section_color.r, section_color.g, section_color.b, 0.18))
	draw_circle(center, radius, Color(health_color.r, health_color.g, health_color.b, 0.92))
	draw_arc(center, radius + 0.5, 0.0, TAU, 24, Color(0.78, 0.95, 1.0, 0.88), 1.2, true)
	draw_rect(Rect2(Vector2(cap_rect.position.x, bar_rect.position.y), Vector2(cap_rect.size.x, bar_rect.size.y)), Color(section_color.r, section_color.g, section_color.b, 0.12), true)


func _draw_energy_waves(section_count: int, margin_x: float, _lane_top: float, shield_bar_y: float, lane_width: float) -> void:
	if _energy_waves.is_empty():
		return
	for wave: Dictionary in _energy_waves:
		var section_id: int = clampi(int(wave["section"]), 0, section_count - 1)
		var progress: float = clampf(float(wave["elapsed"]) / maxf(0.001, energy_wave_duration), 0.0, 1.0)
		var center: Vector2 = _get_core_marker_position(section_id, margin_x, shield_bar_y, lane_width)
		var radius: float = lerpf(4.0, lane_width * energy_wave_radius_scale, progress)
		var alpha: float = (1.0 - progress) * 0.58
		draw_circle(center, radius * 0.28, Color(0.24, 0.74, 1.0, alpha * 0.16))
		draw_arc(center, radius, 0.0, TAU, 40, Color(0.36, 0.82, 1.0, alpha), 2.4, true)
		draw_arc(center, maxf(2.0, radius * 0.62), 0.0, TAU, 36, Color(0.72, 0.96, 1.0, alpha * 0.5), 1.2, true)


func _get_core_marker_position(section_id: int, margin_x: float, shield_bar_y: float, lane_width: float) -> Vector2:
	return Vector2(margin_x + (float(section_id) + 0.5) * lane_width, shield_bar_y + SHIELD_BAR_HEIGHT * 0.5)


func _draw_groups(section_count: int, margin_x: float, lane_top: float, shield_bar_y: float, lane_width: float) -> void:
	var maximum_lane_offset: float = maxf(0.001, _waves.balance.maximum_lane_offset)
	var near_y: float = shield_bar_y - 7.0
	var far_y: float = lane_top + 7.0
	for snapshot: StrategicGroupSnapshot in _waves.get_group_snapshots():
		var section_id: int = clampi(snapshot.section_id, 0, section_count - 1)
		var lane_center_x: float = margin_x + (float(section_id) + 0.5) * lane_width
		var offset_ratio: float = clampf(snapshot.lane_offset / maximum_lane_offset, -1.0, 1.0)
		var marker_position := Vector2(lane_center_x + offset_ratio * lane_width * 0.2, lerpf(near_y, far_y, clampf(snapshot.map_distance, 0.0, 1.0)))
		_draw_group_marker(snapshot, marker_position)


func _draw_group_marker(snapshot: StrategicGroupSnapshot, marker_position: Vector2) -> void:
	var color := Color(0.88, 0.18, 0.18, 0.94)
	if snapshot.is_impacting:
		var pulse: float = 0.72 + sin(_blink_elapsed * 8.0) * 0.2
		color = Color(1.0, 0.32, 0.08, pulse)
		draw_circle(marker_position, 13.0, Color(1.0, 0.12, 0.04, 0.16))
	match get_visual_kind(snapshot.enemy_count):
		&"single":
			_draw_enemy_figure(marker_position, 1.0, color)
		&"pair":
			_draw_enemy_figure(marker_position + Vector2(-4.0, 1.0), 0.9, color)
			_draw_enemy_figure(marker_position + Vector2(4.0, -1.0), 0.9, color.darkened(0.08))
		_:
			_draw_enemy_cloud(snapshot, marker_position, color)


func _draw_enemy_figure(figure_position: Vector2, figure_scale: float, color: Color) -> void:
	draw_circle(figure_position + Vector2(0.0, -2.0) * figure_scale, 2.5 * figure_scale, color)
	var body := PackedVector2Array([
		figure_position + Vector2(-3.2, 0.0) * figure_scale,
		figure_position + Vector2(3.2, 0.0) * figure_scale,
		figure_position + Vector2(2.0, 4.5) * figure_scale,
		figure_position + Vector2(-2.0, 4.5) * figure_scale,
	])
	draw_colored_polygon(body, color.darkened(0.08))
	draw_line(figure_position + Vector2(-1.5, 4.0) * figure_scale, figure_position + Vector2(-2.5, 7.0) * figure_scale, Color(0.16, 0.02, 0.03, 1.0), 1.2)
	draw_line(figure_position + Vector2(1.5, 4.0) * figure_scale, figure_position + Vector2(2.5, 7.0) * figure_scale, Color(0.16, 0.02, 0.03, 1.0), 1.2)


func _draw_enemy_cloud(snapshot: StrategicGroupSnapshot, cloud_position: Vector2, color: Color) -> void:
	var count_scale: float = sqrt(float(snapshot.enemy_count))
	var radius_x: float = clampf(5.0 + count_scale * 1.8, 8.0, 17.0)
	var radius_y: float = clampf(4.0 + count_scale * 1.2, 6.0, 12.0)
	var points := PackedVector2Array()
	var point_count: int = 14
	for index: int in range(point_count):
		var angle: float = TAU * float(index) / float(point_count)
		var phase: float = _blink_elapsed * cloud_morph_speed + float(snapshot.group_id) * 1.37 + float(index) * 2.11
		var wobble: float = 1.0 + sin(phase) * 0.12
		points.append(cloud_position + Vector2(cos(angle) * radius_x * wobble, sin(angle) * radius_y * (2.0 - wobble)))
	draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(0.12, 0.02, 0.02, 0.95), 1.2, true)
	var visible_specks: int = mini(snapshot.enemy_count, 6)
	for index: int in range(visible_specks):
		var speck_seed: float = float(snapshot.group_id * 17 + index * 11)
		var offset := Vector2(sin(_blink_elapsed * 1.7 + speck_seed) * radius_x * 0.45, cos(_blink_elapsed * 2.3 + speck_seed) * radius_y * 0.45)
		draw_circle(cloud_position + offset, 1.3, Color(0.2, 0.02, 0.03, 0.9))


func _update_energy_waves(delta: float) -> void:
	for index: int in range(_energy_waves.size() - 1, -1, -1):
		_energy_waves[index]["elapsed"] = float(_energy_waves[index]["elapsed"]) + delta
		if float(_energy_waves[index]["elapsed"]) >= energy_wave_duration:
			_energy_waves.remove_at(index)


func _on_strategic_enemy_impacted(section_id: int, _damage: float) -> void:
	if not _shield.is_valid_section(section_id):
		return
	_energy_waves.append({"section": section_id, "elapsed": 0.0})
	while _energy_waves.size() > 12:
		_energy_waves.remove_at(0)
	queue_redraw()


func _get_section_health_ratio(section_id: int) -> float:
	if not _shield.is_valid_section(section_id):
		return 0.0
	return clampf(_shield.get_health_percent(section_id) / 100.0, 0.0, 1.0)


func _get_section_health_text(section_id: int) -> String:
	if not _shield.is_valid_section(section_id):
		return ""
	var health_percent: int = roundi(_shield.get_health_percent(section_id))
	var capacity_percent: int = _get_capacity_percent()
	if capacity_percent > 100:
		return "%d  %d/%d%%" % [section_id + 1, health_percent, capacity_percent]
	return "%d  %d%%" % [section_id + 1, health_percent]


func _get_capacity_percent() -> int:
	return roundi(_get_capacity_multiplier() * 100.0)


func _get_capacity_multiplier() -> float:
	var base_max: float = maxf(0.001, _shield.balance.max_health)
	return maxf(1.0, _shield.get_max_health() / base_max)


func _get_health_color(section_id: int) -> Color:
	var percent: float = _shield.get_health_percent(section_id)
	if percent > _shield.balance.indicator_threshold_percent:
		return Color(0.22, 0.88, 0.36)
	if percent > _shield.balance.critical_threshold_percent:
		return Color(1.0, 0.67, 0.12)
	var pulse: float = 0.55 + sin(_blink_elapsed * 7.0) * 0.25
	return Color(1.0, 0.1, 0.08, pulse)
