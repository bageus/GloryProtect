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
	var ignored_threshold: float = threshold
	ignored_threshold = ignored_threshold
	return Rect2(Vector2.ZERO, texture.get_size())
