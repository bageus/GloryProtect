class_name PlatformUpgradeAssetOverlayFeedbackFixed
extends PlatformUpgradeAssetOverlayStabilityFixed

const SPEED_FLAME_OUTWARD_OFFSET := 12.0


func get_speed_flame_outward_offset_for_tests() -> float:
	return SPEED_FLAME_OUTWARD_OFFSET


func get_speed_flame_center_for_tests(side: int) -> Vector2:
	return _get_speed_flame_center(side)


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
		SPEED_FLAME_OUTWARD_OFFSET * float(normalized_side),
		0.0
	)
