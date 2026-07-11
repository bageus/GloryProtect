extends SceneTree

const VISUAL_TEXTURE_PATHS: Array[String] = [
	"res://visual/tiles/tile_platform_base.png",
	"res://visual/tiles/tile_ground_base_01.png",
	"res://visual/defenders/captain_platform/asset_captain_center.png",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert_thresholded_alpha_bounds()
	_assert_project_visuals_are_cropped()
	print("Texture region alpha scenarios passed")
	quit()


func _assert_thresholded_alpha_bounds() -> void:
	var image := Image.create(8, 6, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y: int in range(1, 4):
		for x: int in range(2, 6):
			image.set_pixel(x, y, Color.WHITE)
	image.set_pixel(7, 5, Color(1.0, 1.0, 1.0, 0.04))
	var texture := ImageTexture.create_from_image(image)
	assert(
		TextureRegionLayout.get_alpha_bounds(texture, 0.08)
		== Rect2(Vector2(2.0, 1.0), Vector2(4.0, 3.0))
	)
	assert(
		TextureRegionLayout.get_alpha_bounds(texture, 0.0)
		== Rect2(Vector2(2.0, 1.0), Vector2(6.0, 5.0))
	)


func _assert_project_visuals_are_cropped() -> void:
	for path: String in VISUAL_TEXTURE_PATHS:
		var texture: Texture2D = load(path) as Texture2D
		assert(texture != null, "Missing texture: %s" % path)
		var bounds: Rect2 = TextureRegionLayout.get_alpha_bounds(texture, 0.08)
		assert(bounds.size.x > 0.0 and bounds.size.y > 0.0)
		assert(
			bounds.size.x < texture.get_size().x
			or bounds.size.y < texture.get_size().y,
			"Expected transparent padding to be cropped: %s" % path
		)
