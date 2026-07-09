class_name TextureRegionLayout
extends RefCounted


static func fit_inside(source_size: Vector2, target_size: Vector2) -> Vector2:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return Vector2.ZERO
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		return Vector2.ZERO
	var scale: float = minf(
		target_size.x / source_size.x,
		target_size.y / source_size.y
	)
	return source_size * scale


static func get_alpha_bounds(
	texture: Texture2D,
	threshold: float = 0.0
) -> Rect2:
	if texture == null:
		return Rect2()
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return Rect2(Vector2.ZERO, texture.get_size())
	var width: int = image.get_width()
	var height: int = image.get_height()
	if width <= 0 or height <= 0:
		return Rect2(Vector2.ZERO, texture.get_size())

	var min_x: int = width
	var min_y: int = height
	var max_x: int = -1
	var max_y: int = -1
	var safe_threshold: float = clampf(threshold, 0.0, 1.0)

	for y: int in range(height):
		for x: int in range(width):
			if image.get_pixel(x, y).a <= safe_threshold:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)

	if max_x < min_x or max_y < min_y:
		return Rect2()
	return Rect2(
		Vector2(float(min_x), float(min_y)),
		Vector2(float(max_x - min_x + 1), float(max_y - min_y + 1))
	)
