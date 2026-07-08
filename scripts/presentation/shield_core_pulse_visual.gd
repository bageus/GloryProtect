class_name ShieldCorePulseVisual
extends Node2D

signal pulse_started(source: int, section_id: int)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("ShieldCoreSystem") var shield_core_system_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("ShieldCoreGroundOrbRegistry") var orb_registry_path: NodePath
@export_node_path("AnchorlessControlSystem") var anchorless_control_path: NodePath = NodePath(
	"../AnchorlessControlSystem"
)
@export var style: ShieldCorePulseVisualStyle

var _active_pulses: Array[ShieldCorePulseRuntime] = []
var _started_counts: Dictionary[int, int] = {}
var _anchorless: AnchorlessControlSystem

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _shield_core: ShieldCoreSystem = get_node(shield_core_system_path)
@onready var _platform: PlatformController = get_node(platform_path)
@onready var _orbs: ShieldCoreGroundOrbRegistry = get_node(orb_registry_path)


func _ready() -> void:
	assert(style != null and style.is_valid())
	_shield_core.surge_pulse_requested.connect(_on_surge_pulse_requested)
	_shield_core.focused_retargeted.connect(_on_focused_retargeted)
	_shield_core.completion_energy_shared.connect(_on_completion_energy_shared)
	_shield_core.upgrades_changed.connect(_on_upgrades_changed)
	_game_flow.run_state_changed.connect(_on_run_state_changed)
	_connect_anchorless_system()
	call_deferred("_connect_anchorless_system")
	queue_redraw()


func _process(delta: float) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	var safe_delta := maxf(0.0, delta)
	if safe_delta <= 0.0 or _active_pulses.is_empty():
		return
	for pulse: ShieldCorePulseRuntime in _active_pulses:
		pulse.elapsed += safe_delta
	for index: int in range(_active_pulses.size() - 1, -1, -1):
		if _active_pulses[index].elapsed >= style.duration:
			_active_pulses.remove_at(index)
	queue_redraw()


func _draw() -> void:
	for pulse: ShieldCorePulseRuntime in _active_pulses:
		var progress: float = clampf(pulse.elapsed / style.duration, 0.0, 1.0)
		match pulse.source:
			ShieldCoreSystem.SurgePulseSource.GROUND_CORE:
				_draw_ground_pulse(pulse, progress)
			ShieldCoreSystem.SurgePulseSource.PLATFORM_CORE:
				_draw_platform_pulse(pulse, progress)


func get_active_pulse_count() -> int:
	return _active_pulses.size()


func get_started_pulse_count(source: int) -> int:
	return int(_started_counts.get(source, 0))


func get_oldest_pulse_elapsed_for_tests() -> float:
	if _active_pulses.is_empty():
		return 0.0
	return _active_pulses[0].elapsed


func get_ground_lift_offset_for_tests(progress: float) -> float:
	var clamped: float = clampf(progress, 0.0, 1.0)
	return -style.ground_lift_amplitude * sin(clamped * PI)


func get_ground_pulse_half_width_for_tests(
	progress: float,
	diameter_multiplier: float = 1.0
) -> float:
	return _get_ground_pulse_half_width(progress, diameter_multiplier)


func get_compact_wave_scale_for_tests() -> float:
	return style.compact_wave_scale


func get_spread_wave_scale_for_tests() -> float:
	return style.spread_wave_scale


func is_anchorless_connected_for_tests() -> bool:
	return _anchorless != null


func _connect_anchorless_system() -> void:
	if _anchorless != null:
		return
	_anchorless = get_node_or_null(anchorless_control_path) as AnchorlessControlSystem
	if _anchorless == null:
		return
	if not _anchorless.core_pulse_requested.is_connected(_on_anchorless_core_pulse_requested):
		_anchorless.core_pulse_requested.connect(_on_anchorless_core_pulse_requested)


func _on_surge_pulse_requested(_section_id: int, _source: int) -> void:
	pass


func _on_focused_retargeted(section_id: int, _enemy_count: int) -> void:
	_start_pulse(
		section_id,
		ShieldCoreSystem.SurgePulseSource.GROUND_CORE,
		style.compact_wave_scale
	)


func _on_completion_energy_shared(
	_source_section_id: int,
	target_section_id: int,
	_amount: float
) -> void:
	_start_pulse(
		target_section_id,
		ShieldCoreSystem.SurgePulseSource.GROUND_CORE,
		style.spread_wave_scale
	)


func _on_anchorless_core_pulse_requested(
	section_id: int,
	source: int,
	_event_count: int
) -> void:
	_start_pulse(section_id, source)


func _start_pulse(
	section_id: int,
	source: int,
	diameter_multiplier: float = 1.0
) -> void:
	if not _orbs.is_valid_orb(section_id):
		return
	if source not in [
		ShieldCoreSystem.SurgePulseSource.GROUND_CORE,
		ShieldCoreSystem.SurgePulseSource.PLATFORM_CORE,
	]:
		return
	_active_pulses.append(ShieldCorePulseRuntime.new(
		source,
		section_id,
		diameter_multiplier
	))
	_started_counts[source] = get_started_pulse_count(source) + 1
	pulse_started.emit(source, section_id)
	queue_redraw()


func _draw_ground_pulse(pulse: ShieldCorePulseRuntime, progress: float) -> void:
	var center: Vector2 = _orbs.get_orb_world_position(pulse.section_id)
	center.y = _orbs.catalog.ground_y + style.ground_surface_offset_y
	var half_width: float = _get_ground_pulse_half_width(
		progress,
		pulse.diameter_multiplier
	)
	_draw_ground_surface_lift(center, half_width, progress)
	_draw_wave(
		center,
		half_width,
		progress,
		style.ground_color,
		pulse.section_id * 11 + 3
	)


func _draw_platform_pulse(pulse: ShieldCorePulseRuntime, progress: float) -> void:
	var center := _platform.position + Vector2(
		0.0,
		-_platform.get_platform_height() * 0.5 + style.platform_surface_offset_y
	)
	var half_width: float = maxf(
		4.0,
		_platform.get_platform_width() * 0.5 * _ease_out(progress) * pulse.diameter_multiplier
	)
	_draw_wave(
		center,
		half_width,
		progress,
		style.platform_color,
		pulse.section_id * 13 + 7
	)


func _get_ground_pulse_half_width(
	progress: float,
	diameter_multiplier: float
) -> float:
	return maxf(
		4.0,
		style.ground_max_radius * _ease_out(progress) * diameter_multiplier
	)


func _draw_ground_surface_lift(
	center: Vector2,
	half_width: float,
	progress: float
) -> void:
	var lift: float = get_ground_lift_offset_for_tests(progress)
	if absf(lift) <= 0.01:
		return
	var count: int = maxi(4, style.segment_count)
	var points := PackedVector2Array()
	for index: int in range(count + 1):
		var ratio: float = float(index) / float(count)
		var x: float = lerpf(center.x - half_width, center.x + half_width, ratio)
		var rise: float = sin(ratio * PI)
		points.append(Vector2(x, center.y + lift * rise))
	for index: int in range(count, -1, -1):
		var ratio: float = float(index) / float(count)
		var x: float = lerpf(center.x - half_width, center.x + half_width, ratio)
		var rise: float = sin(ratio * PI)
		points.append(Vector2(
			x,
			center.y + style.ground_lift_band_height + lift * rise * 0.25
		))
	var color: Color = style.ground_lift_color
	color.a *= 1.0 - progress
	draw_colored_polygon(points, color)


func _draw_wave(
	center: Vector2,
	half_width: float,
	progress: float,
	base_color: Color,
	seed: int
) -> void:
	var points := _build_wave_points(center, half_width, progress, seed)
	var alpha: float = style.start_alpha * (1.0 - progress)
	var outer_color := base_color
	outer_color.a = alpha * 0.28
	var inner_color := base_color.lightened(0.55)
	inner_color.a = alpha
	draw_polyline(points, outer_color, style.outer_line_width, true)
	draw_polyline(points, inner_color, style.inner_line_width, true)
	var front_color := base_color.lightened(0.72)
	front_color.a = alpha
	draw_circle(points[0], style.inner_line_width * 1.4, front_color)
	draw_circle(points[points.size() - 1], style.inner_line_width * 1.4, front_color)


func _build_wave_points(
	center: Vector2,
	half_width: float,
	progress: float,
	seed: int
) -> PackedVector2Array:
	var result := PackedVector2Array()
	var count: int = maxi(4, style.segment_count)
	for index: int in range(count + 1):
		var ratio: float = float(index) / float(count)
		var x: float = lerpf(center.x - half_width, center.x + half_width, ratio)
		var edge_fade: float = sin(ratio * PI)
		var phase: float = float(index * 7 + seed) * 0.91 + progress * TAU
		var y_offset: float = (
			sin(phase)
			* style.jitter_amplitude
			* edge_fade
			* (1.0 - progress * 0.45)
		)
		result.append(Vector2(x, center.y + y_offset))
	return result


func _ease_out(value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped, 3.0)


func _on_upgrades_changed() -> void:
	if (
		_shield_core.upgrades.has_focused_specialization()
		or _shield_core.upgrades.has_distributed_specialization()
		or _shield_core.upgrades.has_surge_specialization()
	):
		return
	_active_pulses.clear()
	_started_counts.clear()
	queue_redraw()


func _on_run_state_changed(_previous_state: int, new_state: int) -> void:
	if new_state != GameFlowController.RunState.START_DELAY:
		return
	_active_pulses.clear()
	_started_counts.clear()
	queue_redraw()
