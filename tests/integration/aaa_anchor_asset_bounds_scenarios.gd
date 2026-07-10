extends SceneTree

const TEXTURES: Dictionary[String, Texture2D] = {
	"anchor_base": preload("res://visual/objects/asset_anchor.png"),
	"anchor_magnet": preload("res://visual/objects/asset_anchor_02.png"),
	"clamp_base": preload("res://visual/objects/asset_clamp.png"),
	"clamp_fastening": preload("res://visual/objects/asset_clamp_02.png"),
	"clamp_turbo": preload("res://visual/objects/asset_clamp_03.png"),
	"winch_base": preload("res://visual/objects/asset_winch_01.png"),
	"winch_strong": preload("res://visual/objects/asset_winch_02.png"),
	"winch_electric": preload("res://visual/objects/asset_winch_03.png"),
	"winch_trap": preload("res://visual/objects/asset_winch_04.png"),
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for asset_id: String in TEXTURES:
		var texture: Texture2D = TEXTURES[asset_id]
		var image: Image = texture.get_image()
		var bounds := _get_alpha_bounds(image, 0.08)
		print(
			asset_id,
			" texture=",
			texture.get_size(),
			" alpha_bounds=",
			bounds
		)
	print("Anchor asset bounds scenarios passed")
	quit()


func _get_alpha_bounds(image: Image, threshold: float) -> Rect2i:
	if image == null or image.is_empty():
		return Rect2i()
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a <= threshold:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)
