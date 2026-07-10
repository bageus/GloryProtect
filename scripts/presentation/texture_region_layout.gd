class_name TextureRegionLayout
extends RefCounted

static var _alpha_bounds_cache: Dictionary = {}


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
	var safe_threshold: float = clampf(threshold, 0.0, 1.0)
	var cache_key: String = _get_alpha_cache_key(texture, safe_threshold)
	if _alpha_bounds_cache.has(cache_key):
		return _alpha_bounds_cache[cache_key] as Rect2

	var fallback := Rect2(Vector2.ZERO, texture.get_size())
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		_alpha_bounds_cache[cache_key] = fallback
		return fallback
	var used_rect: Rect2i = image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		_alpha_bounds_cache[cache_key] = fallback
		return fallback

	var left: int = used_rect.position.x
	var top: int = used_rect.position.y
	var right: int = used_rect.position.x + used_rect.size.x - 1
	var bottom: int = used_rect.position.y + used_rect.size.y - 1
	while left <= right and not _column_has_alpha(
		image, left, top, bottom, safe_threshold
	):
		left += 1
	while right >= left and not _column_has_alpha(
		image, right, top, bottom, safe_threshold
	):
		right -= 1
	while top <= bottom and not _row_has_alpha(
		image, top, left, right, safe_threshold
	):
		top += 1
	while bottom >= top and not _row_has_alpha(
		image, bottom, left, right, safe_threshold
	):
		bottom -= 1

	if right < left or bottom < top:
		_alpha_bounds_cache[cache_key] = fallback
		return fallback
	var bounds := Rect2(
		Vector2(float(left), float(top)),
		Vector2(float(right - left + 1), float(bottom - top + 1))
	)
	_alpha_bounds_cache[cache_key] = bounds
	return bounds


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


static func _get_alpha_cache_key(texture: Texture2D, threshold: float) -> String:
	var identity: String = texture.resource_path
	if identity.is_empty():
		identity = str(texture.get_instance_id())
	return "%s|%.4f" % [identity, threshold]


static func _column_has_alpha(
	image: Image,
	x: int,
	top: int,
	bottom: int,
	threshold: float
) -> bool:
	for y: int in range(top, bottom + 1):
		if image.get_pixel(x, y).a > threshold:
			return true
	return false


static func _row_has_alpha(
	image: Image,
	y: int,
	left: int,
	right: int,
	threshold: float
) -> bool:
	for x: int in range(left, right + 1):
		if image.get_pixel(x, y).a > threshold:
			return true
	return false
