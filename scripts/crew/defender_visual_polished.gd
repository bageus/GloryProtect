class_name DefenderVisualPolished
extends DefenderVisual

@export_range(0.0, 80.0, 1.0) var driver_health_bar_raise: float = 34.0


func get_health_bar_raise() -> float:
	return driver_health_bar_raise if _is_live_driver() else 0.0


func _draw_health_segments(asset_rect: Rect2) -> void:
	var adjusted_rect := asset_rect
	adjusted_rect.position.y -= get_health_bar_raise()
	super._draw_health_segments(adjusted_rect)


func _is_live_driver() -> bool:
	if _role_manager != null and _defender != null:
		var assignment: CrewAssignmentRuntime = _role_manager.get_assignment(
			_defender.defender_id
		)
		if assignment != null:
			return (
				assignment.current_role == CrewRole.Id.DRIVER
				and assignment.state == CrewAssignmentRuntime.State.ACTIVE
			)
	return _role_id == CrewRole.Id.DRIVER
