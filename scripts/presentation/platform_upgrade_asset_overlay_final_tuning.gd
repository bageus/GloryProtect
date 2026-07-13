class_name PlatformUpgradeAssetOverlayFinalTuning
extends PlatformUpgradeAssetOverlayFeedbackFixed

const STABILITY_SIZE_MULTIPLIER := 1.3
const STABILITY_OVERLAY_OFFSET_Y := 2.0
const SPEED_FLAME_EXTRA_OUTWARD_OFFSET := 3.0
const CONTROL_ACTIVE_EXTRA_LIFT_Y := 2.0
const FRONT_SWEEP_ARC_RADIUS := 18.0
const FRONT_SWEEP_ARC_GAP := 7.0
const FRONT_SWEEP_ARC_LINE_WIDTH := 2.5


func _draw() -> void:
	_draw_speed_assets()
	_draw_stability_assets()
	_draw_core_overlay()
	_draw_control_mechanism()
	_draw_wind_compensators()
	_draw_front_sweep_arcs()


func get_stability_size_multiplier_for_tests() -> float:
	return STABILITY_SIZE_MULTIPLIER


func get_stability_overlay_offset_y_for_tests() -> float:
	return STABILITY_OVERLAY_OFFSET_Y


func get_speed_flame_extra_outward_offset_for_tests() -> float:
	return SPEED_FLAME_EXTRA_OUTWARD_OFFSET


func get_control_active_extra_lift_for_tests() -> float:
	return CONTROL_ACTIVE_EXTRA_LIFT_Y


func get_front_sweep_arc_radius_for_tests() -> float:
	return FRONT_SWEEP_ARC_RADIUS


func get_front_sweep_arc_centers_for_tests() -> Array[Vector2]:
	return [
		_get_front_sweep_arc_center(-1),
		_get_front_sweep_arc_center(1),
	]


func is_front_sweep_visual_visible_for_tests() -> bool:
	return _anchorless != null and _anchorless.upgrades.front_sweep_enabled


func is_automatic_steering_bundle_ready_for_tests() -> bool:
	return (
		_anchorless != null
		and _anchorless.upgrades.steering_force_bonus_ratio > 0.0
		and _anchorless.upgrades.wind_reduction_ratio > 0.0
		and _anchorless.upgrades.release_drag_bonus_ratio > 0.0
	)


func get_visible_asset_ids_for_tests() -> PackedStringArray:
	var result: PackedStringArray = super.get_visible_asset_ids_for_tests()
	if is_front_sweep_visual_visible_for_tests():
		result.append("ramming_edge")
	return result


func _get_speed_flame_outward_offset() -> float:
	return (
		super._get_speed_flame_outward_offset()
		+ SPEED_FLAME_EXTRA_OUTWARD_OFFSET
	)


func _get_correct_stability_layout(
	side: int,
	overlay_texture: Texture2D
) -> Dictionary:
	var layout: Dictionary = super._get_correct_stability_layout(
		side,
		overlay_texture
	)
	var normalized_side: int = -1 if side < 0 else 1
	var base_source: Rect2 = layout["base_source"]
	var overlay_source: Rect2 = layout["overlay_source"]
	var base_scale: float = float(layout["base_scale"]) * STABILITY_SIZE_MULTIPLIER
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
			+ STABILITY_OVERLAY_OFFSET_Y
	)
	layout["base_scale"] = base_scale
	layout["base_size"] = base_size
	layout["overlay_size"] = overlay_size
	layout["base_center"] = base_center
	layout["overlay_center"] = overlay_center
	return layout


func _get_control_active_center() -> Vector2:
	return super._get_control_active_center() + Vector2(
		0.0,
		-CONTROL_ACTIVE_EXTRA_LIFT_Y
	)


func _draw_front_sweep_arcs() -> void:
	if not is_front_sweep_visual_visible_for_tests():
		return
	for side: int in [-1, 1]:
		var center: Vector2 = _get_front_sweep_arc_center(side)
		var start_angle: float = -PI * 0.5 if side > 0 else PI * 0.5
		var end_angle: float = PI * 0.5 if side > 0 else PI * 1.5
		draw_arc(
			center,
			FRONT_SWEEP_ARC_RADIUS,
			start_angle,
			end_angle,
			20,
			Color(0.38, 0.9, 1.0, 0.86),
			FRONT_SWEEP_ARC_LINE_WIDTH,
			true
		)
		draw_arc(
			center,
			FRONT_SWEEP_ARC_RADIUS * 0.68,
			start_angle,
			end_angle,
			16,
			Color(0.82, 0.98, 1.0, 0.58),
			1.2,
			true
		)


func _get_front_sweep_arc_center(side: int) -> Vector2:
	var normalized_side: int = -1 if side < 0 else 1
	var platform_half_width: float = (
		360.0
		if _platform == null
		else _platform.get_platform_width() * 0.5
	)
	return Vector2(
		float(normalized_side) * (
			platform_half_width
			+ FRONT_SWEEP_ARC_GAP
			+ FRONT_SWEEP_ARC_RADIUS
		),
		0.0
	)
