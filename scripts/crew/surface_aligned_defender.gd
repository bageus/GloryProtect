class_name SurfaceAlignedDefender
extends Defender


func _apply_configuration(reset_life_state: bool) -> void:
	super._apply_configuration(reset_life_state)
	_align_visual_to_platform_surface()


func get_visual_feet_platform_local_y() -> float:
	if visual == null:
		return position.y
	return (
		position.y
		+ visual.position.y
		+ visual.body_radius
		+ visual.asset_offset.y
	)


func _align_visual_to_platform_surface() -> void:
	if visual == null or get_parent() == null:
		return
	var platform := get_parent().get_parent() as PlatformController
	if platform == null:
		return
	var surface_local_y: float = -platform.get_platform_height() * 0.5
	var visual_feet_local_y: float = visual.body_radius + visual.asset_offset.y
	visual.position.y = surface_local_y - position.y - visual_feet_local_y
