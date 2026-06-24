class_name GroundSurfaceVisual
extends RefCounted

const GROUND_BASE_PATHS: Array[String] = [
	"res://visual/tiles/tile_ground_base_01.png",
	"res://visual/tiles/tile_ground_base_02.png",
]
const GRASS_PATHS: Array[String] = [
	"res://visual/tiles/grass/tile_ground_grass_01.png",
	"res://visual/tiles/grass/tile_ground_grass_02.png",
	"res://visual/tiles/grass/tile_ground_grass_03.png",
	"res://visual/tiles/grass/tile_ground_grass_04.png",
	"res://visual/tiles/grass/tile_ground_grass_05.png",
	"res://visual/tiles/grass/tile_ground_grass_06.png",
]

var _ground_textures: Array[Texture2D] = []
var _grass_textures: Array[Texture2D] = []
var _ground_source_rects: Array[Rect2] = []
var _grass_source_rects: Array[Rect2] = []


func configure(alpha_crop_threshold: float) -> void:
	_ground_textures = _load_textures(GROUND_BASE_PATHS)
	_grass_textures = _load_textures(GRASS_PATHS)
	_ground_source_rects.clear()
	for texture: Texture2D in _ground_textures:
		_ground_source_rects.append(TextureRegionLayout.get_alpha_bounds(
			texture,
			alpha_crop_threshold
		))
	_grass_source_rects.clear()
	for texture: Texture2D in _grass_textures:
		_grass_source_rects.append(TextureRegionLayout.get_alpha_bounds(
			texture,
			alpha_crop_threshold
		))


func draw(
	canvas: CanvasItem,
	world_min_x: float,
	world_max_x: float,
	ground_y: float,
	ground_depth: float,
	tile_size: Vector2,
	tile_overlap: float,
	vertical_offset: float,
	grass_count_range: Vector2i,
	grass_max_size: Vector2,
	grass_vertical_range: Vector2,
	grass_horizontal_margin_ratio: float
) -> void:
	var ground_rect := Rect2(
		Vector2(world_min_x, ground_y),
		Vector2(world_max_x - world_min_x, ground_depth)
	)
	canvas.draw_rect(ground_rect, Color(0.045, 0.065, 0.08), true)
	if _ground_textures.is_empty():
		return

	var tile_width: float = maxf(tile_size.x, 1.0)
	var first_tile_index: int = floori(world_min_x / tile_width)
	var tile_index: int = first_tile_index
	var tile_x: float = float(first_tile_index) * tile_width
	while tile_x < world_max_x:
		_draw_tile(
			canvas,
			tile_index,
			Vector2(tile_x, ground_y + vertical_offset),
			tile_size,
			tile_overlap,
			grass_count_range,
			grass_max_size,
			grass_vertical_range,
			grass_horizontal_margin_ratio
		)
		tile_index += 1
		tile_x += tile_width


func _draw_tile(
	canvas: CanvasItem,
	tile_index: int,
	tile_position: Vector2,
	tile_size: Vector2,
	tile_overlap: float,
	grass_count_range: Vector2i,
	grass_max_size: Vector2,
	grass_vertical_range: Vector2,
	grass_horizontal_margin_ratio: float
) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = _get_tile_seed(tile_index)
	var half_overlap: float = tile_overlap * 0.5
	var tile_rect := Rect2(
		tile_position - Vector2(half_overlap, 0.0),
		Vector2(tile_size.x + tile_overlap, tile_size.y)
	)
	var base_index: int = random.randi_range(
		0,
		_ground_textures.size() - 1
	)
	canvas.draw_texture_rect_region(
		_ground_textures[base_index],
		tile_rect,
		_ground_source_rects[base_index]
	)
	_draw_grass(
		canvas,
		random,
		tile_rect,
		grass_count_range,
		grass_max_size,
		grass_vertical_range,
		grass_horizontal_margin_ratio
	)


func _draw_grass(
	canvas: CanvasItem,
	random: RandomNumberGenerator,
	tile_rect: Rect2,
	grass_count_range: Vector2i,
	grass_max_size: Vector2,
	grass_vertical_range: Vector2,
	grass_horizontal_margin_ratio: float
) -> void:
	if _grass_textures.is_empty():
		return
	var minimum_count: int = clampi(
		mini(grass_count_range.x, grass_count_range.y),
		0,
		_grass_textures.size()
	)
	var maximum_count: int = clampi(
		maxi(grass_count_range.x, grass_count_range.y),
		minimum_count,
		_grass_textures.size()
	)
	var grass_count: int = random.randi_range(minimum_count, maximum_count)
	var available_indices: Array[int] = []
	for index: int in range(_grass_textures.size()):
		available_indices.append(index)

	var margin_ratio: float = clampf(grass_horizontal_margin_ratio, 0.0, 0.45)
	var min_vertical: float = clampf(
		minf(grass_vertical_range.x, grass_vertical_range.y),
		0.0,
		1.0
	)
	var max_vertical: float = clampf(
		maxf(grass_vertical_range.x, grass_vertical_range.y),
		min_vertical,
		1.0
	)
	for _grass_index: int in range(grass_count):
		var pool_index: int = random.randi_range(0, available_indices.size() - 1)
		var texture_index: int = available_indices[pool_index]
		available_indices.remove_at(pool_index)
		var source_rect: Rect2 = _grass_source_rects[texture_index]
		var draw_size: Vector2 = TextureRegionLayout.fit_inside(
			source_rect.size,
			grass_max_size
		)
		var grass_center := Vector2(
			random.randf_range(
				tile_rect.position.x + tile_rect.size.x * margin_ratio,
				tile_rect.end.x - tile_rect.size.x * margin_ratio
			),
			random.randf_range(
				tile_rect.position.y + tile_rect.size.y * min_vertical,
				tile_rect.position.y + tile_rect.size.y * max_vertical
			)
		)
		var mirror_scale := (
			Vector2(-1.0, 1.0)
			if random.randi_range(0, 1) == 1
			else Vector2.ONE
		)
		canvas.draw_set_transform(grass_center, 0.0, mirror_scale)
		canvas.draw_texture_rect_region(
			_grass_textures[texture_index],
			Rect2(-draw_size * 0.5, draw_size),
			source_rect
		)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _get_tile_seed(tile_index: int) -> int:
	return absi(tile_index * 92821 + 17389)


func _load_textures(paths: Array[String]) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for resource_path: String in paths:
		var resource: Resource = ResourceLoader.load(resource_path)
		var texture: Texture2D = resource as Texture2D
		if texture == null:
			push_error("GroundSurfaceVisual could not load %s" % resource_path)
			continue
		textures.append(texture)
	return textures
