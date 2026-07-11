class_name AnchorVisualControllerFasteningScaled
extends AnchorVisualControllerPolished

const FASTENING_CLAMP_SCALE_MULTIPLIER := 0.9


func get_active_clamp_scale_multiplier_for_tests() -> float:
	return _get_active_clamp_scale_multiplier()


func get_active_clamp_unscaled_visual_size_for_tests() -> Vector2:
	return _get_active_clamp_unscaled_visual_size()


func get_active_clamp_visual_size_for_tests() -> Vector2:
	return (
		_get_active_clamp_unscaled_visual_size()
		* _get_active_clamp_scale_multiplier()
	)


func _get_clamp_visual_rect(ground: Vector2) -> Rect2:
	var size := (
		_get_active_clamp_unscaled_visual_size()
		* _get_active_clamp_scale_multiplier()
	)
	var bottom := ground + clamp_ground_offset
	return Rect2(bottom + Vector2(-size.x * 0.5, -size.y), size)


func _draw_clamp_texture(
	ground: Vector2,
	texture: Texture2D,
	source_rect: Rect2,
	tint: Color
) -> void:
	var source_size: Vector2 = source_rect.size
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		source_size = Vector2(42.0, 34.0)
	var size := (
		source_size
		* get_clamp_visual_scale()
		* _get_active_clamp_scale_multiplier()
	)
	var bottom := ground + clamp_ground_offset
	var rect := Rect2(bottom + Vector2(-size.x * 0.5, -size.y), size)
	draw_texture_rect_region(texture, rect, source_rect, tint)


func _get_active_clamp_unscaled_visual_size() -> Vector2:
	var source_rect: Rect2 = _get_active_clamp_source_rect()
	var source_size: Vector2 = source_rect.size
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		source_size = Vector2(42.0, 34.0)
	return source_size * get_clamp_visual_scale()


func _get_active_clamp_scale_multiplier() -> float:
	var asset_id: StringName = _get_combat_clamp_asset_id()
	if asset_id in [&"fastening", &"turbo_fastening"]:
		return FASTENING_CLAMP_SCALE_MULTIPLIER
	return 1.0
