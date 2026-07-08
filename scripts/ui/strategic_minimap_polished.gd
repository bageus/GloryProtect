class_name StrategicMinimapPolished
extends StrategicMinimap

const CORE_BURST_TEXTURE: Texture2D = preload(
	"res://visual/objects/platform/core/asset_core_energy_splash.png"
)

@export_node_path("ShieldCoreSystem") var shield_core_system_path: NodePath = NodePath(
	"../../World/ShieldCoreSystem"
)
@export_range(1.0, 3.0, 0.1) var cloud_size_multiplier: float = 1.6
@export_range(0.1, 0.35, 0.01) var cloud_wobble_amount: float = 0.2
@export_range(0.1, 1.2, 0.05) var core_burst_duration: float = 0.55
@export_range(8.0, 80.0, 1.0) var core_burst_max_radius: float = 34.0
@export_range(8.0, 80.0, 1.0) var core_burst_asset_size: float = 24.0
@export_range(0.2, 2.6, 0.05) var core_burst_arc_angle: float = 1.05
@export_range(0.0, 1.0, 0.01) var core_burst_alpha_crop_threshold: float = 0.08

var _shield_core: ShieldCoreSystem
var _core_bursts: Array[Dictionary] = []
var _core_burst_source_rect: Rect2


func _ready() -> void:
	cloud_morph_speed = 2.1
	_core_burst_source_rect = TextureRegionLayout.get_alpha_bounds(
		CORE_BURST_TEXTURE,
		core_burst_alpha_crop_threshold
	)
	super._ready()
	_connect_shield_core_system()
	call_deferred("_connect_shield_core_system")


func _process(delta: float) -> void:
	super._process(delta)
	_connect_shield_core_system()
	var simulation_active: bool = (
		_game_flow == null or _game_flow.is_world_simulation_active()
	)
	if not simulation_active:
		return
	_update_core_bursts(maxf(0.0, delta))
	queue_redraw()


func _draw() -> void:
	super._draw()
	_draw_core_bursts()


func get_cloud_radius(enemy_count: int) -> Vector2:
	var count_scale: float = sqrt(float(maxi(1, enemy_count)))
	return Vector2(
		clampf(7.0 + count_scale * 2.4, 11.0, 21.0),
		clampf(5.0 + count_scale * 1.65, 8.0, 15.0)
	) * cloud_size_multiplier


func get_active_core_burst_count_for_tests() -> int:
	return _core_bursts.size()


func has_core_burst_for_section_for_tests(section_id: int) -> bool:
	for burst: Dictionary in _core_bursts:
		if int(burst["section"]) == section_id:
			return true
	return false


func get_latest_core_burst_angle_for_tests() -> float:
	if _core_bursts.is_empty():
		return 0.0
	return float(_core_bursts[_core_bursts.size() - 1]["angle"])


func get_latest_core_burst_center_for_tests() -> Vector2:
	if _core_bursts.is_empty():
		return Vector2.ZERO
	var burst: Dictionary = _core_bursts[_core_bursts.size() - 1]
	return _get_core_burst_center(int(burst["section"]), _get_core_burst_metrics())


func get_core_burst_direction_for_section_for_tests(section_id: int) -> Vector2:
	var metrics: Dictionary = _get_core_burst_metrics()
	return _get_core_burst_direction(section_id, metrics)


func debug_emit_core_burst_for_tests(section_id: int, source: int) -> void:
	_on_surge_pulse_requested(section_id, source)


func _draw_enemy_cloud(
	snapshot: StrategicGroupSnapshot,
	cloud_position: Vector2,
	color: Color
) -> void:
	var radius: Vector2 = get_cloud_radius(snapshot.enemy_count)
	var points := PackedVector2Array()
	var point_count: int = 18
	var time: float = _blink_elapsed * cloud_morph_speed
	var breathing: float = 1.0 + sin(
		time * 0.72 + float(snapshot.group_id)
	) * 0.07

	for index: int in range(point_count):
		var angle: float = TAU * float(index) / float(point_count)
		var phase: float = (
			time
			+ float(snapshot.group_id) * 1.37
			+ float(index) * 1.73
		)
		var secondary: float = (
			sin(time * 1.63 - float(index) * 0.91) * 0.06
		)
		var wobble: float = (
			1.0
			+ sin(phase) * cloud_wobble_amount
			+ secondary
		)
		points.append(
			cloud_position + Vector2(
				cos(angle) * radius.x * wobble * breathing,
				sin(angle) * radius.y * (2.0 - wobble) * breathing
			)
		)

	draw_circle(
		cloud_position,
		maxf(radius.x, radius.y) * 1.08,
		Color(color.r, color.g, color.b, 0.12)
	)
	draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(
		outline,
		Color(0.08, 0.01, 0.02, 1.0),
		2.0,
		true
	)

	var visible_specks: int = mini(snapshot.enemy_count, 8)
	for index: int in range(visible_specks):
		var speck_seed: float = float(snapshot.group_id * 17 + index * 11)
		var orbit: float = (
			time * (0.42 + float(index % 3) * 0.09) + speck_seed
		)
		var offset := Vector2(
			sin(orbit * 1.7) * radius.x * 0.55,
			cos(orbit * 2.3) * radius.y * 0.46
		)
		draw_circle(
			cloud_position + offset,
			1.7 + sin(orbit) * 0.35,
			Color(0.18, 0.01, 0.025, 0.95)
		)


func _connect_shield_core_system() -> void:
	if _shield_core != null:
		return
	_shield_core = get_node_or_null(shield_core_system_path) as ShieldCoreSystem
	if _shield_core == null:
		return
	if not _shield_core.surge_pulse_requested.is_connected(_on_surge_pulse_requested):
		_shield_core.surge_pulse_requested.connect(_on_surge_pulse_requested)


func _on_surge_pulse_requested(section_id: int, source: int) -> void:
	if not _is_core_burst_source(source):
		return
	if not _shield.is_valid_section(section_id):
		return
	var metrics: Dictionary = _get_core_burst_metrics()
	var direction: Vector2 = _get_core_burst_direction(section_id, metrics)
	_core_bursts.append({
		"section": section_id,
		"elapsed": 0.0,
		"angle": direction.angle(),
	})
	while _core_bursts.size() > 8:
		_core_bursts.remove_at(0)
	queue_redraw()


func _is_core_burst_source(source: int) -> bool:
	return source in [
		ShieldCoreSystem.SurgePulseSource.GROUND_CORE,
		ShieldCoreSystem.SurgePulseSource.PLATFORM_CORE,
	]


func _draw_core_bursts() -> void:
	if _core_bursts.is_empty() or _shield.get_section_count() <= 0:
		return
	var metrics: Dictionary = _get_core_burst_metrics()
	for burst: Dictionary in _core_bursts:
		var progress: float = clampf(
			float(burst["elapsed"]) / maxf(0.001, core_burst_duration),
			0.0,
			1.0
		)
		var center: Vector2 = _get_core_burst_center(
			int(burst["section"]),
			metrics
		)
		_draw_core_burst(center, float(burst["angle"]), progress)


func _draw_core_burst(center: Vector2, angle: float, progress: float) -> void:
	var eased: float = 1.0 - pow(1.0 - progress, 3.0)
	var alpha: float = (1.0 - progress) * 0.86
	var radius: float = lerpf(5.0, core_burst_max_radius, eased)
	var start_angle: float = angle - core_burst_arc_angle * 0.5
	var end_angle: float = angle + core_burst_arc_angle * 0.5
	draw_arc(center, radius, start_angle, end_angle, 24, Color(1.0, 0.08, 0.04, alpha), 2.8, true)
	draw_arc(center, radius * 0.62, start_angle, end_angle, 20, Color(1.0, 0.42, 0.26, alpha * 0.7), 1.4, true)
	draw_circle(center, 4.0 + eased * 4.0, Color(1.0, 0.1, 0.06, alpha * 0.26))
	_draw_core_burst_asset(center, angle, alpha)


func _draw_core_burst_asset(center: Vector2, angle: float, alpha: float) -> void:
	if _core_burst_source_rect.size.x <= 0.0 or _core_burst_source_rect.size.y <= 0.0:
		return
	var asset_size := Vector2(core_burst_asset_size, core_burst_asset_size)
	var draw_size: Vector2 = TextureRegionLayout.fit_inside(
		_core_burst_source_rect.size,
		asset_size
	)
	draw_set_transform(center, angle, Vector2.ONE)
	draw_texture_rect_region(
		CORE_BURST_TEXTURE,
		Rect2(-draw_size * 0.5, draw_size),
		_core_burst_source_rect,
		Color(1.0, 0.12, 0.06, alpha)
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _get_core_burst_metrics() -> Dictionary:
	var section_count: int = maxi(1, _shield.get_section_count())
	var margin_x: float = 8.0
	var lane_top: float = 30.0
	var lane_bottom: float = _get_lane_bottom()
	var shield_bar_y: float = lane_bottom - SHIELD_BAR_HEIGHT
	var lane_width: float = (_get_map_width() - margin_x * 2.0) / float(section_count)
	return {
		"lane_top": lane_top,
		"margin_x": margin_x,
		"lane_width": lane_width,
		"shield_bar_y": shield_bar_y,
	}


func _get_core_burst_center(section_id: int, metrics: Dictionary) -> Vector2:
	var section_count: int = maxi(1, _shield.get_section_count())
	var clamped_section: int = clampi(section_id, 0, section_count - 1)
	return _get_core_marker_position(
		clamped_section,
		float(metrics["margin_x"]),
		float(metrics["shield_bar_y"]),
		float(metrics["lane_width"])
	)


func _get_core_burst_direction(section_id: int, metrics: Dictionary) -> Vector2:
	var center: Vector2 = _get_core_burst_center(section_id, metrics)
	var target := Vector2(center.x, float(metrics["lane_top"]))
	var direction: Vector2 = target - center
	if direction.length_squared() <= 0.01:
		return Vector2.UP
	return direction.normalized()


func _update_core_bursts(delta: float) -> void:
	for index: int in range(_core_bursts.size() - 1, -1, -1):
		_core_bursts[index]["elapsed"] = float(_core_bursts[index]["elapsed"]) + delta
		if float(_core_bursts[index]["elapsed"]) >= core_burst_duration:
			_core_bursts.remove_at(index)
