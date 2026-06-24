class_name PlatformSurfaceVisual
extends RefCounted

const PLATFORM_TILE_PATH: String = "res://visual/tiles/tile_platform_base.png"
const PLATFORM_BORDER_PATH: String = "res://visual/tiles/tile_platform_border.png"
const PLATFORM_CORE_ATLAS_PATH: String = "res://visual/tiles/atlas_platform_core_normal.png"

var _platform_tile_texture: Texture2D
var _platform_border_texture: Texture2D
var _platform_core_atlas: Texture2D
var _platform_tile_source_rect: Rect2
var _platform_border_source_rect: Rect2
var _platform_core_frame_regions: Array[Rect2] = []
var _animation_elapsed: float = 0.0


func configure(
	atlas_frame_count: int,
	alpha_crop_threshold: float
) -> void:
	_platform_tile_texture = _load_texture(PLATFORM_TILE_PATH)
	_platform_border_texture = _load_texture(PLATFORM_BORDER_PATH)
	_platform_core_atlas = _load_texture(PLATFORM_CORE_ATLAS_PATH)
	if _platform_tile_texture != null:
		_platform_tile_source_rect = TextureRegionLayout.get_alpha_bounds(
			_platform_tile_texture,
			alpha_crop_threshold
		)
	if _platform_border_texture != null:
		_platform_border_source_rect = TextureRegionLayout.get_alpha_bounds(
			_platform_border_texture,
			alpha_crop_threshold
		)
	_platform_core_frame_regions.clear()
	if _platform_core_atlas != null:
		_platform_core_frame_regions = (
			TextureRegionLayout.get_auto_atlas_frame_regions(
				_platform_core_atlas,
				atlas_frame_count,
				alpha_crop_threshold
			)
		)


func advance(delta: float) -> void:
	_animation_elapsed += maxf(0.0, delta)


func draw_body(
	canvas: CanvasItem,
	platform_width: float,
	platform_height: float,
	cell_count: int,
	cell_width: float,
	tile_overlap: float
) -> void:
	var platform_rect := Rect2(
		Vector2(-platform_width * 0.5, -platform_height * 0.5),
		Vector2(platform_width, platform_height)
	)
	canvas.draw_rect(platform_rect, Color(0.12, 0.17, 0.24), true)
	_draw_tiles(
		canvas,
		platform_width,
		platform_height,
		cell_count,
		cell_width,
		tile_overlap
	)
	canvas.draw_rect(
		platform_rect,
		Color(0.55, 0.69, 0.82, 0.45),
		false,
		2.0
	)


func draw_core(
	canvas: CanvasItem,
	platform_height: float,
	maximum_size: Vector2,
	protrusion_ratio: float,
	offset: Vector2,
	frame_rate: float,
	driver_available: bool
) -> void:
	if _platform_core_atlas == null or _platform_core_frame_regions.is_empty():
		return
	var frame_index: int = (
		floori(_animation_elapsed * maxf(frame_rate, 0.01))
		% _platform_core_frame_regions.size()
	)
	var source_rect: Rect2 = _platform_core_frame_regions[frame_index]
	var core_size: Vector2 = TextureRegionLayout.fit_inside(
		source_rect.size,
		maximum_size
	)
	var platform_bottom: float = platform_height * 0.5
	var core_center_y: float = (
		platform_bottom
		+ (protrusion_ratio - 0.5) * core_size.y
	)
	var core_center := Vector2(0.0, core_center_y) + offset
	var core_rect := Rect2(core_center - core_size * 0.5, core_size)
	var core_tint := Color.WHITE
	if not driver_available:
		core_tint = Color(0.42, 0.46, 0.5, 1.0)
	canvas.draw_texture_rect_region(
		_platform_core_atlas,
		core_rect,
		source_rect,
		core_tint
	)


func _draw_tiles(
	canvas: CanvasItem,
	platform_width: float,
	platform_height: float,
	cell_count: int,
	cell_width: float,
	tile_overlap: float
) -> void:
	if _platform_tile_texture == null or _platform_border_texture == null:
		return
	var first_x: float = -platform_width * 0.5
	var half_overlap: float = tile_overlap * 0.5
	for index: int in range(cell_count):
		var tile_rect := Rect2(
			Vector2(
				first_x + float(index) * cell_width - half_overlap,
				-platform_height * 0.5
			),
			Vector2(cell_width + tile_overlap, platform_height)
		)
		if index == 0:
			canvas.draw_texture_rect_region(
				_platform_border_texture,
				tile_rect,
				_platform_border_source_rect
			)
		elif index == cell_count - 1:
			_draw_mirrored_border(canvas, tile_rect)
		else:
			canvas.draw_texture_rect_region(
				_platform_tile_texture,
				tile_rect,
				_platform_tile_source_rect
			)


func _draw_mirrored_border(canvas: CanvasItem, destination: Rect2) -> void:
	if _platform_border_texture == null:
		return
	canvas.draw_set_transform(
		destination.get_center(),
		0.0,
		Vector2(-1.0, 1.0)
	)
	canvas.draw_texture_rect_region(
		_platform_border_texture,
		Rect2(-destination.size * 0.5, destination.size),
		_platform_border_source_rect
	)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _load_texture(resource_path: String) -> Texture2D:
	var resource: Resource = ResourceLoader.load(resource_path)
	var texture: Texture2D = resource as Texture2D
	if texture == null:
		push_error("PlatformSurfaceVisual could not load %s" % resource_path)
	return texture
