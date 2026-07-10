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


static func fit_height(source_size: Vector2, target_height: float) -> Vector2:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return Vector2.ZERO
	if target_height <= 0.0:
		return Vector2.ZERO
	var scale: float = target_height / source_size.y
	return source_size * scale


static func fit_width(source_size: Vector2, target_width: float) -> Vector2:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return Vector2.ZERO
	if target_width <= 0.0:
		return Vector2.ZERO
	var scale: float = target_width / source_size.x
	return source_size * scale


static func get_alpha_bounds(
	texture: Texture2D,
	threshold: float = 0.0
) -> Rect2:
	if texture == null:
		return Rect2()
	var fallback := Rect2(Vector2.ZERO, texture.get_size())
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return fallback
	var used_rect: Rect2i = image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return fallback

	var minimum := Vector2i(
		used_rect.position.x + used_rect.size.x,
		used_rect.position.y + used_rect.size.y
	)
	var maximum := Vector2i(-1, -1)
	var safe_threshold: float = clampf(threshold, 0.0, 1.0)
	var end_x: int = used_rect.position.x + used_rect.size.x
	var end_y: int = used_rect.position.y + used_rect.size.y
	for y: int in range(used_rect.position.y, end_y):
		for x: int in range(used_rect.position.x, end_x):
			if image.get_pixel(x, y).a <= safe_threshold:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)

	if maximum.x < minimum.x or maximum.y < minimum.y:
		return fallback
	return Rect2(
		Vector2(float(minimum.x), float(minimum.y)),
		Vector2(
			float(maximum.x - minimum.x + 1),
			float(maximum.y - minimum.y + 1)
		)
	)


static func get_auto_atlas_frame_regions(
	atlas: Texture2D,
	frame_count: int,
	threshold: float = 0.0
) -> Array[Rect2]:
	var regions: Array[Rect2] = []
	if atlas == null or frame_count <= 0:
		return regions
	var ignored_threshold: float = threshold
	ignored_threshold = ignored_threshold
	var atlas_size: Vector2 = atlas.get_size()
	if atlas_size.x <= 0.0 or atlas_size.y <= 0.0:
		return regions
	var frame_width: float = atlas_size.x / float(frame_count)
	for index: int in range(frame_count):
		regions.append(Rect2(
			Vector2(frame_width * float(index), 0.0),
			Vector2(frame_width, atlas_size.y)
		))
	return regions
