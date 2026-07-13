class_name StrategicMinimapRechargeCoreScaled
extends StrategicMinimapPolished

const RECHARGE_CORE_SCALE_MULTIPLIER := 2.0


func get_recharge_core_scale_multiplier_for_tests() -> float:
	return RECHARGE_CORE_SCALE_MULTIPLIER


func get_current_core_scale_for_tests() -> float:
	return _get_recharge_core_scale()


func _draw_core_bulge(
	section_id: int,
	bar_rect: Rect2,
	health_color: Color
) -> void:
	var center: Vector2 = bar_rect.get_center()
	var section_color: Color = _shield.get_section_color(section_id)
	var pulse: float = (
		0.88
		+ sin(_blink_elapsed * 2.4 + float(section_id)) * 0.07
	)
	var radius: float = CORE_BULGE_RADIUS * pulse * _get_recharge_core_scale()
	var cap_rect := Rect2(
		center - Vector2(radius, radius),
		Vector2(radius * 2.0, radius * 2.0)
	)
	draw_circle(
		center,
		radius + 2.0,
		Color(section_color.r, section_color.g, section_color.b, 0.18)
	)
	draw_circle(
		center,
		radius,
		Color(health_color.r, health_color.g, health_color.b, 0.92)
	)
	draw_arc(
		center,
		radius + 0.5,
		0.0,
		TAU,
		32,
		Color(0.78, 0.95, 1.0, 0.88),
		1.2,
		true
	)
	draw_rect(
		Rect2(
			Vector2(cap_rect.position.x, bar_rect.position.y),
			Vector2(cap_rect.size.x, bar_rect.size.y)
		),
		Color(section_color.r, section_color.g, section_color.b, 0.12),
		true
	)


func _get_recharge_core_scale() -> float:
	if (
		_shield_core != null
		and _shield_core.upgrades.recharge_bonus_ratio > 0.0
	):
		return RECHARGE_CORE_SCALE_MULTIPLIER
	return 1.0
