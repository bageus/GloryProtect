class_name DefenderVisualPolished
extends DefenderVisual

@export_range(0.0, 80.0, 1.0) var driver_health_bar_raise: float = 34.0


func get_health_bar_raise() -> float:
	return driver_health_bar_raise if _role_id == CrewRole.Id.DRIVER else 0.0


func _draw_health_segments(asset_rect: Rect2) -> void:
	var adjusted_rect := asset_rect
	adjusted_rect.position.y -= get_health_bar_raise()
	super._draw_health_segments(adjusted_rect)
