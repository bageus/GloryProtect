class_name ShieldCorePulseVisualStyle
extends Resource

const FOCUSED_VISUAL_SCALE: float = 0.75
const DISTRIBUTED_VISUAL_SCALE: float = 1.1

@export_range(0.05, 2.0, 0.05) var duration: float = 0.65
@export_range(32.0, 2000.0, 8.0) var ground_max_radius: float = 420.0
@export_range(0.0, 64.0, 1.0) var ground_surface_offset_y: float = 4.0
@export_range(-32.0, 32.0, 1.0) var platform_surface_offset_y: float = 2.0
@export_range(4, 48, 1) var segment_count: int = 18
@export_range(0.0, 32.0, 1.0) var jitter_amplitude: float = 9.0
@export_range(1.0, 24.0, 1.0) var outer_line_width: float = 10.0
@export_range(1.0, 12.0, 1.0) var inner_line_width: float = 3.0
@export_range(0.0, 1.0, 0.05) var start_alpha: float = 0.9
@export_range(0.0, 48.0, 1.0) var ground_lift_amplitude: float = 14.0
@export_range(1.0, 96.0, 1.0) var ground_lift_band_height: float = 26.0
@export_range(0.5, 1.5, 0.01) var compact_wave_scale: float = FOCUSED_VISUAL_SCALE
@export_range(0.5, 1.5, 0.01) var spread_wave_scale: float = DISTRIBUTED_VISUAL_SCALE
@export var ground_color: Color = Color(0.38, 0.96, 1.0, 1.0)
@export var platform_color: Color = Color(0.58, 0.72, 1.0, 1.0)
@export var ground_lift_color: Color = Color(0.62, 0.82, 0.92, 0.34)


func is_valid() -> bool:
	return (
		duration > 0.0
		and ground_max_radius > 0.0
		and segment_count >= 4
		and jitter_amplitude >= 0.0
		and outer_line_width >= inner_line_width
		and inner_line_width > 0.0
		and start_alpha > 0.0
		and ground_lift_amplitude >= 0.0
		and ground_lift_band_height > 0.0
		and compact_wave_scale > 0.0
		and spread_wave_scale > 0.0
	)
