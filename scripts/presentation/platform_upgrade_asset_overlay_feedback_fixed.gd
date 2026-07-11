class_name PlatformUpgradeAssetOverlayFeedbackFixed
extends PlatformUpgradeAssetOverlayStabilityFixed

# Five pixels farther toward each outer edge than the previous 16 px inset.
const SPEED_FLAME_EDGE_INSET := 11.0


func get_speed_flame_edge_inset_for_tests() -> float:
	return SPEED_FLAME_EDGE_INSET


func get_speed_flame_outward_offset_for_tests() -> float:
	return _get_speed_flame_outward_offset()


func get_speed_flame_center_for_tests(side: int) -> Vector2:
	return _get_speed_flame_center(side)


func get_speed_engine_visible_outer_edge_for_tests(side: int) -> float:
	var normalized_side: int = -1 if side < 0 else 1
	return _get_speed_asset_center(normalized_side).x + (
		_get_speed_engine_visible_outer_offset() * float(normalized_side)
	)


func get_stability_base_asset_path_for_tests() -> String:
	return STABILITY_BASE.resource_path


func get_stability_overlay_asset_paths_for_tests() -> PackedStringArray:
	return PackedStringArray([
		STABILITY_FLAME_1.resource_path,
		STABILITY_FLAME_2.resource_path,
		STABILITY_FLAME_3.resource_path,
	])


func get_stability_base_centers_for_tests() -> Array[Vector2]:
	return [
		_get_correct_stability_layout(-1, STABILITY_FLAME_1)["base_center"],
		_get_correct_stability_layout(1, STABILITY_FLAME_1)["base_center"],
	]


func get_stability_base_draw_size_for_tests() -> Vector2:
	return _get_correct_stability_layout(1, STABILITY_FLAME_1)["base_size"]


func get_stability_overlay_center_for_tests(side: int) -> Vector2:
	return _get_correct_stability_layout(
		side,
		STABILITY_FLAME_1
	)["overlay_center"]


func get_stability_overlay_draw_size_for_tests() -> Vector2:
	return _get_correct_stability_layout(1, STABILITY_FLAME_1)["overlay_size"]


func get_stability_base_scale_for_tests() -> float:
	return _get_correct_stability_layout(1, STABILITY_FLAME_1)["base_scale"]


func _draw_speed_assets() -> void:
	if not is_speed_asset_visible():
		return
	var flame_side: int = get_active_speed_flame_side_for_tests()
	for side: int in [-1, 1]:
		var center: Vector2 = _get_speed_asset_center(side)
		_draw_speed_texture_aligned(SPEED_ENGINE, center, side < 0)
		if flame_side == side:
			_draw_speed_texture_aligned(
				_get_frame(_speed_flames),
				_get_speed_flame_center(side),
				side < 0
			)


func _draw_stability_assets() -> void:
	if not is_stability_asset_visible():
		return
	var active_side: int = _last_direction
	var active_frame: Texture2D = _get_frame(_stability_flames)
	for side: int in [-1, 1]:
		var layout: Dictionary = _get_correct_stability_layout(
			side,
			active_frame
		)
		_draw_stability_texture(
			STABILITY_BASE,
			layout["base_source"],
			layout["base_center"],
			layout["base_size"],
			layout["mirrored"]
		)
		if is_stability_pulse_active_for_tests() and active_side == side:
			_draw_stability_texture(
				active_frame,
				layout["overlay_source"],
				layout["overlay_center"],
				layout["overlay_size"],
				layout["mirrored"]
			)


func _get_all_textures() -> Array[Texture2D]:
	var textures: Array[Texture2D] = super._get_all_textures()
	for texture: Texture2D in [
		STABILITY_BASE,
		STABILITY_FLAME_1,
		STABILITY_FLAME_2,
		STABILITY_FLAME_3,
	]:
		if not textures.has(texture):
			textures.append(texture)
	return textures


func _get_correct_stability_layout(
	side: int,
	overlay_texture: Texture2D
) -> Dictionary:
	var normalized_side: int = -1 if side < 0 else 1
	var base_source: Rect2 = _source_rects.get(STABILITY_BASE, Rect2())
	var overlay_source: Rect2 = _source_rects.get(overlay_texture, Rect2())
	var base_scale: float = _get_stability_base_scale(base_source)
	var base_size: Vector2 = base_source.size * base_scale
	var overlay_size: Vector2 = overlay_source.size * base_scale
	var base_center: Vector2 = _get_stability_base_center(
		normalized_side,
		base_size
	)
	var overlay_center := Vector2(
		base_center.x,
		base_center.y
			+ base_size.y * 0.5
			- overlay_size.y * 0.5
			- stability_overlay_bottom_padding
	)
	return {
		"base_source": base_source,
		"overlay_source": overlay_source,
		"base_center": base_center,
		"overlay_center": overlay_center,
		"base_size": base_size,
		"overlay_size": overlay_size,
		"base_scale": base_scale,
		"mirrored": normalized_side < 0,
	}


func _get_speed_flame_center(side: int) -> Vector2:
	var normalized_side: int = -1 if side < 0 else 1
	return _get_speed_asset_center(normalized_side) + Vector2(
		_get_speed_flame_outward_offset() * float(normalized_side),
		0.0
	)


func _get_speed_flame_outward_offset() -> float:
	return maxf(
		0.0,
		_get_speed_engine_visible_outer_offset() - SPEED_FLAME_EDGE_INSET
	)


func _get_speed_engine_visible_outer_offset() -> float:
	var common_rect: Rect2 = _speed_common_source_rect
	var engine_rect: Rect2 = _source_rects.get(SPEED_ENGINE, Rect2())
	if common_rect.size.x <= 0.0 or engine_rect.size.x <= 0.0:
		return speed_engine_size.x * 0.5
	var draw_scale: float = speed_engine_size.x / common_rect.size.x
	var visible_right_edge: float = (
		(engine_rect.end.x - common_rect.position.x) * draw_scale
		- speed_engine_size.x * 0.5
	)
	return clampf(visible_right_edge, 0.0, speed_engine_size.x * 0.5)
