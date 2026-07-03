class_name CombatAnchorVisualController
extends AnchorVisualController

const REINFORCED_CHAIN_TEXTURE: Texture2D = preload(
	"res://visual/tiles/tile_chain_rainforce.png"
)

@export_range(1.0, 8.0, 0.25) var electric_arc_speed: float = 4.5
@export_range(4.0, 20.0, 1.0) var electric_arc_spacing: float = 10.0
@export_range(1.0, 8.0, 0.5) var electric_arc_amplitude: float = 4.0
@export_range(0.05, 1.5, 0.05) var trap_burst_duration: float = 0.42
@export_range(0.0, 1.0, 0.05) var trap_burst_start_alpha: float = 0.82

var _anchor_host: CombatAnchorHostSystem
var _combat_anchors: CombatAnchorSystem
var _trap_bursts: Array[Dictionary] = []
var _reinforced_chain_source_rect: Rect2


func _ready() -> void:
	super._ready()
	_reinforced_chain_source_rect = TextureRegionLayout.get_alpha_bounds(
		REINFORCED_CHAIN_TEXTURE,
		alpha_crop_threshold
	)


func configure_combat(
	store: AnchorRuntimeStore,
	geometry: AnchorGeometry,
	balance: AnchorBalance,
	is_operator_available: Callable,
	is_simulation_active: Callable,
	anchor_host: CombatAnchorHostSystem,
	combat_anchors: CombatAnchorSystem
) -> void:
	_anchor_host = anchor_host
	_combat_anchors = combat_anchors
	configure(
		store,
		geometry,
		balance,
		is_operator_available,
		is_simulation_active
	)
	if _combat_anchors == null:
		return
	if not _combat_anchors.upgrades_changed.is_connected(_on_upgrades_changed):
		_combat_anchors.upgrades_changed.connect(_on_upgrades_changed)
	if not _combat_anchors.trap_triggered.is_connected(_on_trap_triggered):
		_combat_anchors.trap_triggered.connect(_on_trap_triggered)


func _process(delta: float) -> void:
	super._process(delta)
	var safe_delta: float = maxf(0.0, delta)
	if safe_delta <= 0.0 or _trap_bursts.is_empty():
		return
	for burst: Dictionary in _trap_bursts:
		burst["elapsed"] = float(burst["elapsed"]) + safe_delta
	for index: int in range(_trap_bursts.size() - 1, -1, -1):
		if float(_trap_bursts[index]["elapsed"]) >= trap_burst_duration:
			_trap_bursts.remove_at(index)
	queue_redraw()


func _draw() -> void:
	super._draw()
	_draw_trap_bursts()


func is_electric_visual_active(anchor_id: int) -> bool:
	if _anchor_host == null or _combat_anchors == null or anchor_id < 0:
		return false
	if not (
		_combat_anchors.upgrades.periodic_electric_enabled
		or _combat_anchors.upgrades.has_electric_specialization()
	):
		return false
	var state: int = _anchor_host.get_anchor_state(anchor_id)
	return state in [
		AnchorRuntime.State.ATTACHED,
		AnchorRuntime.State.OVERLOADED,
	]


func is_reinforced_chain_visual_active() -> bool:
	return (
		_combat_anchors != null
		and _combat_anchors.upgrades.has_strong_specialization()
	)


func get_active_trap_burst_count() -> int:
	return _trap_bursts.size()


func get_latest_trap_burst_position() -> Vector2:
	if _trap_bursts.is_empty():
		return Vector2(INF, INF)
	return _trap_bursts[_trap_bursts.size() - 1]["position"] as Vector2


func get_latest_trap_burst_radius() -> float:
	if _trap_bursts.is_empty():
		return 0.0
	return float(_trap_bursts[_trap_bursts.size() - 1]["radius"])


func _draw_stowed_anchor(anchor: AnchorRuntime, start: Vector2) -> void:
	super._draw_stowed_anchor(anchor, start)
	if not is_reinforced_chain_visual_active():
		return
	_draw_reinforced_chain_overlay(
		start,
		start + Vector2(0.0, stowed_chain_length),
		Color(1.0, 0.95, 0.72, 1.0)
	)


func _draw_installing_anchor(anchor: AnchorRuntime, start: Vector2) -> void:
	super._draw_installing_anchor(anchor, start)
	if not is_reinforced_chain_visual_active():
		return
	var target: Vector2 = _get_clamp_connection_point(anchor.target_ground_point)
	var ratio := clampf(
		anchor.operation_progress / maxf(_balance.install_duration, 0.01),
		0.0,
		1.0
	)
	_draw_reinforced_chain_overlay(
		start,
		start.lerp(target, ratio),
		Color(1.0, 0.93, 0.62, 1.0)
	)


func _draw_attached_anchor(
	anchor: AnchorRuntime,
	start: Vector2,
	ground: Vector2
) -> void:
	super._draw_attached_anchor(anchor, start, ground)
	if is_reinforced_chain_visual_active():
		_draw_reinforced_chain_overlay(
			start,
			_get_clamp_connection_point(ground),
			Color(1.0, 0.88, 0.48, 1.0)
		)
	if not is_electric_visual_active(anchor.anchor_id):
		return
	_draw_electric_arcs(
		start,
		_get_clamp_connection_point(ground),
		anchor.anchor_id
	)


func _draw_returning_anchor(
	anchor: AnchorRuntime,
	start: Vector2,
	ground: Vector2
) -> void:
	super._draw_returning_anchor(anchor, start, ground)
	if not is_reinforced_chain_visual_active():
		return
	var ratio := clampf(
		anchor.operation_progress / maxf(_balance.return_duration, 0.01),
		0.0,
		1.0
	)
	var source := _get_clamp_connection_point(ground)
	var top := source.lerp(start + Vector2(0.0, stowed_chain_length), ratio)
	_draw_reinforced_chain_overlay(source, top, Color(0.98, 0.86, 0.52, 1.0))


func _draw_reinforced_chain_overlay(start: Vector2, finish: Vector2, tint: Color) -> void:
	var segment := finish - start
	var length := segment.length()
	if length <= 0.01:
		return
	var direction := segment / length
	var tile_size: Vector2 = TextureRegionLayout.fit_height(
		_reinforced_chain_source_rect.size,
		chain_tile_height
	)
	var spacing: float = maxf(
		tile_size.y * (1.0 - chain_tile_overlap_ratio),
		1.0
	)
	var link_positions := calculate_chain_link_positions(start, finish, spacing)
	var link_rotation := direction.angle() - PI * 0.5
	var rect := Rect2(-tile_size * 0.5, tile_size)
	for link_position: Vector2 in link_positions:
		draw_set_transform(link_position, link_rotation, Vector2.ONE)
		draw_texture_rect_region(
			REINFORCED_CHAIN_TEXTURE,
			rect,
			_reinforced_chain_source_rect,
			tint
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_electric_arcs(
	start: Vector2,
	finish: Vector2,
	anchor_id: int
) -> void:
	var segment: Vector2 = finish - start
	var length: float = segment.length()
	if length <= 1.0:
		return
	var direction: Vector2 = segment / length
	var normal := direction.rotated(PI * 0.5)
	var point_count: int = maxi(5, ceili(length / electric_arc_spacing))
	var phase: float = (
		_warning_elapsed * electric_arc_speed + float(anchor_id) * 1.91
	)
	var arc := PackedVector2Array()
	for index: int in range(point_count + 1):
		var ratio: float = float(index) / float(point_count)
		var arc_point: Vector2 = start.lerp(finish, ratio)
		var envelope: float = sin(ratio * PI)
		var jitter: float = (
			sin(phase + float(index) * 2.37)
			+ sin(phase * 1.73 - float(index) * 1.19) * 0.45
		)
		arc_point += normal * jitter * electric_arc_amplitude * envelope
		arc.append(arc_point)
	draw_polyline(
		arc,
		Color(0.3, 0.82, 1.0, 0.55),
		5.0,
		true
	)
	draw_polyline(
		arc,
		Color(0.88, 0.98, 1.0, 1.0),
		2.0,
		true
	)

	var branch_count: int = maxi(2, floori(length / 80.0))
	for branch_index: int in range(branch_count):
		var ratio: float = fposmod(
			phase * 0.11 + float(branch_index) / float(branch_count),
			1.0
		)
		var origin: Vector2 = start.lerp(finish, ratio)
		var side: float = -1.0 if branch_index % 2 == 0 else 1.0
		var branch_end := (
			origin
			+ normal * electric_arc_amplitude * 2.4 * side
			+ direction * 6.0
		)
		draw_line(
			origin,
			branch_end,
			Color(0.75, 0.96, 1.0, 0.9),
			1.5,
			true
		)


func _draw_trap_bursts() -> void:
	for burst: Dictionary in _trap_bursts:
		var elapsed: float = float(burst["elapsed"])
		var progress: float = clampf(
			elapsed / maxf(0.01, trap_burst_duration),
			0.0,
			1.0
		)
		var center: Vector2 = burst["position"] as Vector2
		var radius: float = float(burst["radius"])
		var wave_radius: float = maxf(4.0, radius * _ease_out(progress))
		var alpha: float = trap_burst_start_alpha * (1.0 - progress)
		var ring := Color(1.0, 0.68, 0.18, alpha)
		var glow := Color(1.0, 0.24, 0.08, alpha * 0.22)
		draw_circle(center, wave_radius * 0.55, glow)
		draw_arc(center, wave_radius, 0.0, TAU, 36, ring, 5.0, true)
		var spoke_count: int = 8
		for index: int in range(spoke_count):
			var angle: float = float(index) / float(spoke_count) * TAU
			var direction := Vector2.RIGHT.rotated(angle)
			var inner: Vector2 = center + direction * wave_radius * 0.35
			var outer: Vector2 = center + direction * wave_radius * 0.92
			draw_line(inner, outer, ring.lightened(0.28), 2.0, true)


func _on_trap_triggered(
	_anchor_id: int,
	world_position: Vector2,
	radius: float,
	_damaged_enemy_count: int,
	_source_id: StringName
) -> void:
	_trap_bursts.append({
		"position": world_position,
		"radius": maxf(4.0, radius),
		"elapsed": 0.0,
	})
	queue_redraw()


func _on_upgrades_changed() -> void:
	queue_redraw()


func _ease_out(value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped, 3.0)
