class_name PlatformUpgradeAssetOverlayFeedbackFixed
extends PlatformUpgradeAssetOverlayStabilityFixed

const SPEED_FLAME_EDGE_INSET := 16.0


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
