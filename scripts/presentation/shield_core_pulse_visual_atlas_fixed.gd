class_name ShieldCorePulseVisualAtlasFixed
extends ShieldCorePulseVisual

const GROUND_PULSE_ATLAS: Texture2D = preload(
	"res://visual/tiles/atlas_ground_core_red.png"
)
const PLATFORM_PULSE_ATLAS: Texture2D = preload(
	"res://visual/tiles/atlas_platform_core_red.png"
)
const PULSE_ATLAS_FRAME_COUNT := 6
const PULSE_ALPHA_CROP_THRESHOLD := 0.08

@export var ground_pulse_atlas_size := Vector2(256.0, 128.0)
@export var ground_pulse_vertical_offset: float = 12.0
@export var platform_pulse_atlas_size := Vector2(92.0, 92.0)
@export_range(0.0, 1.0, 0.01) var platform_core_protrusion_ratio := 0.38
@export var platform_core_offset := Vector2(0.0, 12.0)

var _ground_pulse_frame_regions: Array[Rect2] = []
var _platform_pulse_frame_regions: Array[Rect2] = []


func _ready() -> void:
	super._ready()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ground_pulse_frame_regions = _build_pulse_frame_regions(
		GROUND_PULSE_ATLAS
	)
	_platform_pulse_frame_regions = _build_pulse_frame_regions(
		PLATFORM_PULSE_ATLAS
	)


func get_ground_pulse_atlas_path_for_tests() -> String:
	return GROUND_PULSE_ATLAS.resource_path


func get_platform_pulse_atlas_path_for_tests() -> String:
	return PLATFORM_PULSE_ATLAS.resource_path


func get_ground_pulse_frame_count_for_tests() -> int:
	return _ground_pulse_frame_regions.size()


func get_platform_pulse_frame_count_for_tests() -> int:
	return _platform_pulse_frame_regions.size()


func get_ground_pulse_frame_for_tests(progress: float) -> Rect2:
	return _get_pulse_frame(_ground_pulse_frame_regions, progress)


func get_platform_pulse_frame_for_tests(progress: float) -> Rect2:
	return _get_pulse_frame(_platform_pulse_frame_regions, progress)


func _draw_ground_pulse(
	pulse: ShieldCorePulseRuntime,
	progress: float
) -> void:
	if _ground_pulse_frame_regions.is_empty():
		super._draw_ground_pulse(pulse, progress)
		return
	var center: Vector2 = _orbs.get_orb_world_position(pulse.section_id)
	center += Vector2(0.0, ground_pulse_vertical_offset)
	_draw_pulse_atlas_frame(
		GROUND_PULSE_ATLAS,
		_ground_pulse_frame_regions,
		center,
		ground_pulse_atlas_size * pulse.diameter_multiplier,
		progress
	)


func _draw_platform_pulse(
	pulse: ShieldCorePulseRuntime,
	progress: float
) -> void:
	if _platform_pulse_frame_regions.is_empty():
		super._draw_platform_pulse(pulse, progress)
		return
	var source_rect: Rect2 = _get_pulse_frame(
		_platform_pulse_frame_regions,
		progress
	)
	var maximum_size := platform_pulse_atlas_size * pulse.diameter_multiplier
	var draw_size: Vector2 = TextureRegionLayout.fit_inside(
		source_rect.size,
		maximum_size
	)
	var platform_bottom: float = _platform.get_platform_height() * 0.5
	var core_center_y: float = (
		platform_bottom
		+ (platform_core_protrusion_ratio - 0.5) * draw_size.y
	)
	var center := _platform.position + Vector2(0.0, core_center_y) + (
		platform_core_offset
	)
	_draw_pulse_atlas_region(
		PLATFORM_PULSE_ATLAS,
		source_rect,
		center,
		draw_size
	)


func _draw_pulse_atlas_frame(
	atlas: Texture2D,
	frame_regions: Array[Rect2],
	center: Vector2,
	maximum_size: Vector2,
	progress: float
) -> void:
	var source_rect: Rect2 = _get_pulse_frame(frame_regions, progress)
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return
	var draw_size: Vector2 = TextureRegionLayout.fit_inside(
		source_rect.size,
		maximum_size
	)
	_draw_pulse_atlas_region(atlas, source_rect, center, draw_size)


func _draw_pulse_atlas_region(
	atlas: Texture2D,
	source_rect: Rect2,
	center: Vector2,
	draw_size: Vector2
) -> void:
	if atlas == null:
		return
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return
	draw_texture_rect_region(
		atlas,
		Rect2(center - draw_size * 0.5, draw_size),
		source_rect,
		Color.WHITE
	)


func _get_pulse_frame(
	frame_regions: Array[Rect2],
	progress: float
) -> Rect2:
	if frame_regions.is_empty():
		return Rect2()
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	var frame_index: int = mini(
		floori(clamped_progress * float(frame_regions.size())),
		frame_regions.size() - 1
	)
	return frame_regions[frame_index]


func _build_pulse_frame_regions(atlas: Texture2D) -> Array[Rect2]:
	if atlas == null:
		return []
	return TextureRegionLayout.get_auto_atlas_frame_regions(
		atlas,
		PULSE_ATLAS_FRAME_COUNT,
		PULSE_ALPHA_CROP_THRESHOLD
	)
