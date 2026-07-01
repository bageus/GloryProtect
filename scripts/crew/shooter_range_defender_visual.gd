class_name ShooterRangeDefenderVisual
extends DefenderVisualPolished

const SHOOTER_RANGE_FILL_COLOR := Color(1.0, 0.32, 0.16, 0.12)
const SHOOTER_RANGE_OUTLINE_COLOR := Color(1.0, 0.56, 0.24, 0.82)

var _attack_range_context_visible: bool = false


func set_attack_range_context_visible(visible_value: bool) -> void:
	if _attack_range_context_visible == visible_value:
		return
	_attack_range_context_visible = visible_value
	queue_redraw()


func is_attack_range_visible() -> bool:
	return (
		_attack_range_context_visible
		and _selected
		and _state != AnimationState.DYING
		and _state != AnimationState.HIDDEN
		and _defender != null
		and _defender.health.is_alive()
		and _is_effective_shooter()
		and get_displayed_attack_range() > 0.0
	)


func get_displayed_attack_range() -> float:
	if _ranged == null or _ranged.profile == null:
		return 0.0
	return _ranged.profile.maximum_range


func get_attack_range_center_global() -> Vector2:
	if _defender == null:
		return global_position
	return _defender.global_position


func get_attack_range_fill_color() -> Color:
	return SHOOTER_RANGE_FILL_COLOR


func get_attack_range_outline_color() -> Color:
	return SHOOTER_RANGE_OUTLINE_COLOR


func _draw() -> void:
	if is_attack_range_visible():
		_draw_shooter_attack_range()
	super._draw()


func _draw_shooter_attack_range() -> void:
	var radius: float = get_displayed_attack_range()
	var center: Vector2 = to_local(get_attack_range_center_global())
	draw_circle(center, radius, SHOOTER_RANGE_FILL_COLOR)
	draw_arc(
		center,
		radius,
		0.0,
		TAU,
		96,
		SHOOTER_RANGE_OUTLINE_COLOR,
		2.0
	)


func _is_effective_shooter() -> bool:
	if _defender == null:
		return false
	var polished_roles := _role_manager as ShooterCrewRoleManagerPolished
	if polished_roles != null:
		return (
			polished_roles.get_combat_role(_defender.defender_id)
			== CrewRole.Id.SHOOTER
		)
	return _role_id == CrewRole.Id.SHOOTER
