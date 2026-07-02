class_name ShieldCoreCriticalIndicator
extends Control

@export_node_path("ShieldSystem") var shield_system_path: NodePath
@export_node_path("GroundOrbRegistry") var orb_registry_path: NodePath
@export_range(0.2, 8.0, 0.1) var onscreen_visible_seconds: float = 2.0
@export_range(0.0, 240.0, 1.0) var edge_margin: float = 32.0
@export_range(0.0, 240.0, 1.0) var top_safe_margin: float = 96.0
@export_range(0.0, 240.0, 1.0) var bottom_safe_margin: float = 132.0
@export_range(16.0, 96.0, 1.0) var marker_radius: float = 28.0
@export_range(0.0, 1.0, 0.05) var fill_alpha: float = 0.86

var _onscreen_elapsed: Dictionary[int, float] = {}
var _was_offscreen: Dictionary[int, bool] = {}
var _snapshots: Dictionary[int, Dictionary] = {}

@onready var _shield: ShieldSystem = get_node(shield_system_path)
@onready var _orbs: GroundOrbRegistry = get_node(orb_registry_path)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	assert(_shield != null, "ShieldCoreCriticalIndicator requires ShieldSystem")
	assert(_orbs != null, "ShieldCoreCriticalIndicator requires GroundOrbRegistry")
	queue_redraw()


func _process(delta: float) -> void:
	_rebuild_snapshots(maxf(0.0, delta))
	queue_redraw()


func _draw() -> void:
	for section_id: int in _get_sorted_snapshot_ids():
		var snapshot: Dictionary = _snapshots[section_id]
		if not bool(snapshot["visible"]):
			continue
		_draw_marker(section_id, snapshot)


func get_visible_indicator_count() -> int:
	var count: int = 0
	for snapshot: Dictionary in _snapshots.values():
		if bool(snapshot["visible"]):
			count += 1
	return count


func is_indicator_visible(section_id: int) -> bool:
	if not _snapshots.has(section_id):
		return false
	return bool(_snapshots[section_id]["visible"])


func is_indicator_offscreen(section_id: int) -> bool:
	if not _snapshots.has(section_id):
		return false
	return bool(_snapshots[section_id]["offscreen"])


func get_indicator_position(section_id: int) -> Vector2:
	if not _snapshots.has(section_id):
		return Vector2(INF, INF)
	return _snapshots[section_id]["position"] as Vector2


func get_indicator_angle(section_id: int) -> float:
	if not _snapshots.has(section_id):
		return 0.0
	return float(_snapshots[section_id]["angle"])


func get_onscreen_elapsed(section_id: int) -> float:
	return float(_onscreen_elapsed.get(section_id, 0.0))


func _rebuild_snapshots(delta: float) -> void:
	_snapshots.clear()
	var alive_ids: Dictionary[int, bool] = {}
	for section_id: int in range(_shield.get_section_count()):
		if not _shield.is_critical(section_id):
			continue
		alive_ids[section_id] = true
		var world_position: Vector2 = _orbs.get_orb_world_position(section_id)
		var screen_position: Vector2 = _world_to_screen(world_position)
		var offscreen: bool = not _get_view_rect().has_point(screen_position)
		_update_section_timer(section_id, offscreen, delta)
		var visible: bool = offscreen or get_onscreen_elapsed(section_id) < onscreen_visible_seconds
		_snapshots[section_id] = {
			"visible": visible,
			"offscreen": offscreen,
			"position": _get_marker_position(section_id, screen_position, offscreen),
			"target": screen_position,
			"angle": _get_marker_angle(screen_position, offscreen),
		}
	_prune_stale_state(alive_ids)


func _update_section_timer(section_id: int, offscreen: bool, delta: float) -> void:
	if offscreen:
		_onscreen_elapsed[section_id] = 0.0
		_was_offscreen[section_id] = true
		return
	if bool(_was_offscreen.get(section_id, true)):
		_onscreen_elapsed[section_id] = 0.0
	else:
		_onscreen_elapsed[section_id] = get_onscreen_elapsed(section_id) + delta
	_was_offscreen[section_id] = false


func _prune_stale_state(alive_ids: Dictionary[int, bool]) -> void:
	for section_id: int in _onscreen_elapsed.keys():
		if not alive_ids.has(section_id):
			_onscreen_elapsed.erase(section_id)
	for section_id: int in _was_offscreen.keys():
		if not alive_ids.has(section_id):
			_was_offscreen.erase(section_id)


func _world_to_screen(world_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_position


func _get_view_rect() -> Rect2:
	var viewport_size: Vector2 = size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport().get_visible_rect().size
	return Rect2(Vector2.ZERO, viewport_size)


func _get_safe_rect() -> Rect2:
	var view_rect: Rect2 = _get_view_rect()
	var left: float = view_rect.position.x + edge_margin
	var top: float = view_rect.position.y + top_safe_margin
	var right: float = view_rect.end.x - edge_margin
	var bottom: float = view_rect.end.y - bottom_safe_margin
	if right < left:
		right = left
	if bottom < top:
		bottom = top
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))


func _get_marker_position(
	section_id: int,
	screen_position: Vector2,
	offscreen: bool
) -> Vector2:
	if offscreen:
		return _clamp_to_safe_rect(screen_position, section_id)
	return screen_position + Vector2(0.0, -marker_radius * 1.65)


func _clamp_to_safe_rect(screen_position: Vector2, section_id: int) -> Vector2:
	var safe_rect: Rect2 = _get_safe_rect()
	var clamped_position := Vector2(
		clampf(screen_position.x, safe_rect.position.x, safe_rect.end.x),
		clampf(screen_position.y, safe_rect.position.y, safe_rect.end.y)
	)
	var duplicate_offset: float = float(section_id % 3 - 1) * marker_radius * 0.55
	if is_equal_approx(clamped_position.x, safe_rect.position.x) or is_equal_approx(
		clamped_position.x,
		safe_rect.end.x
	):
		clamped_position.y = clampf(
			clamped_position.y + duplicate_offset,
			safe_rect.position.y,
			safe_rect.end.y
		)
	else:
		clamped_position.x = clampf(
			clamped_position.x + duplicate_offset,
			safe_rect.position.x,
			safe_rect.end.x
		)
	return clamped_position


func _get_marker_angle(screen_position: Vector2, offscreen: bool) -> float:
	if offscreen:
		var center: Vector2 = _get_view_rect().get_center()
		var direction: Vector2 = screen_position - center
		if direction.length_squared() <= 0.01:
			direction = Vector2.UP
		return direction.angle()
	return PI * 0.5


func _draw_marker(section_id: int, snapshot: Dictionary) -> void:
	var marker_position: Vector2 = snapshot["position"] as Vector2
	var angle: float = float(snapshot["angle"])
	var color: Color = _shield.get_section_color(section_id)
	var fill := color.lightened(0.18)
	fill.a = fill_alpha
	var border := Color(1.0, 0.24, 0.14, 0.96)
	var points: PackedVector2Array = _build_arrow_points(marker_position, angle)
	draw_colored_polygon(points, fill)
	draw_polyline(points, border, 3.0, true)
	draw_circle(marker_position, marker_radius * 0.58, Color(0.08, 0.02, 0.02, 0.72))
	draw_string(
		ThemeDB.fallback_font,
		marker_position + Vector2(-marker_radius * 0.36, marker_radius * 0.18),
		"S%d" % (section_id + 1),
		HORIZONTAL_ALIGNMENT_LEFT,
		marker_radius * 1.1,
		18,
		Color(1.0, 0.96, 0.88, 1.0)
	)


func _build_arrow_points(center: Vector2, angle: float) -> PackedVector2Array:
	var forward := Vector2.RIGHT.rotated(angle)
	var right := forward.rotated(PI * 0.5)
	return PackedVector2Array([
		center + forward * marker_radius * 1.25,
		center - forward * marker_radius * 0.88 + right * marker_radius * 0.82,
		center - forward * marker_radius * 0.42,
		center - forward * marker_radius * 0.88 - right * marker_radius * 0.82,
	])


func _get_sorted_snapshot_ids() -> Array[int]:
	var ids: Array[int] = []
	for section_id: int in _snapshots.keys():
		ids.append(section_id)
	ids.sort()
	return ids
