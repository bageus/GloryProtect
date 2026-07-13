class_name ShieldCorePulseVisualRadiusFixed
extends ShieldCorePulseVisualAtlasFixed

const ANCHORLESS_CORE_PULSE_RADIUS := 320.0
const GROUND_PULSE_HEIGHT_RATIO := 0.2


func get_anchorless_core_pulse_radius_for_tests() -> float:
	return ANCHORLESS_CORE_PULSE_RADIUS


func get_ground_radius_wave_half_width_for_tests(
	progress: float,
	diameter_multiplier: float = 1.0
) -> float:
	return _get_radius_wave_radius(progress, diameter_multiplier)


func get_platform_radius_wave_radius_for_tests(
	progress: float,
	diameter_multiplier: float = 1.0
) -> float:
	return _get_radius_wave_radius(progress, diameter_multiplier)


func _draw_ground_pulse(
	pulse: ShieldCorePulseRuntime,
	progress: float
) -> void:
	super._draw_ground_pulse(pulse, progress)
	_draw_ground_radius_wave(pulse, progress)


func _draw_platform_pulse(
	pulse: ShieldCorePulseRuntime,
	progress: float
) -> void:
	super._draw_platform_pulse(pulse, progress)
	_draw_platform_radius_wave(pulse, progress)


func _draw_ground_radius_wave(
	pulse: ShieldCorePulseRuntime,
	progress: float
) -> void:
	var center: Vector2 = _orbs.get_orb_world_position(pulse.section_id)
	center.y = _orbs.catalog.ground_y + style.ground_surface_offset_y
	var radius: float = _get_radius_wave_radius(
		progress,
		pulse.diameter_multiplier
	)
	var vertical_radius: float = maxf(5.0, radius * GROUND_PULSE_HEIGHT_RATIO)
	var points := PackedVector2Array()
	var inner_points := PackedVector2Array()
	var segment_count := 48
	for index: int in range(segment_count + 1):
		var ratio: float = float(index) / float(segment_count)
		var angle: float = lerpf(PI, TAU, ratio)
		points.append(center + Vector2(
			cos(angle) * radius,
			sin(angle) * vertical_radius
		))
		inner_points.append(center + Vector2(
			cos(angle) * radius * 0.76,
			sin(angle) * vertical_radius * 0.58
		))
	var alpha: float = (1.0 - clampf(progress, 0.0, 1.0)) * 0.86
	draw_polyline(
		points,
		Color(1.0, 0.16, 0.08, alpha),
		3.0,
		true
	)
	draw_polyline(
		inner_points,
		Color(1.0, 0.66, 0.32, alpha * 0.7),
		1.5,
		true
	)


func _draw_platform_radius_wave(
	pulse: ShieldCorePulseRuntime,
	progress: float
) -> void:
	var platform_bottom: float = _platform.get_platform_height() * 0.5
	var core_center_y: float = (
		platform_bottom
		+ (platform_core_protrusion_ratio - 0.5) * platform_pulse_atlas_size.y
	)
	var center := _platform.position + Vector2(0.0, core_center_y) + (
		platform_core_offset
	)
	var radius: float = _get_radius_wave_radius(
		progress,
		pulse.diameter_multiplier
	)
	var alpha: float = (1.0 - clampf(progress, 0.0, 1.0)) * 0.82
	draw_arc(
		center,
		radius,
		0.0,
		TAU,
		64,
		Color(1.0, 0.12, 0.08, alpha),
		3.0,
		true
	)
	draw_arc(
		center,
		radius * 0.7,
		0.0,
		TAU,
		56,
		Color(1.0, 0.58, 0.3, alpha * 0.68),
		1.5,
		true
	)


func _get_radius_wave_radius(
	progress: float,
	diameter_multiplier: float
) -> float:
	var clamped: float = clampf(progress, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - clamped, 3.0)
	return lerpf(
		10.0,
		ANCHORLESS_CORE_PULSE_RADIUS * maxf(0.01, diameter_multiplier),
		eased
	)
