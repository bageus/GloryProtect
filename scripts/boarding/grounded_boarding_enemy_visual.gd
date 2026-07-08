class_name GroundedBoardingEnemyVisual
extends BoardingEnemyVisual

@export_range(0.0, 32.0, 0.5) var fast_idle_ground_offset_y: float = 6.0


func get_asset_feet_y_for_tests(state_id: StringName) -> float:
	var previous_state: StringName = _presentation_state_id
	_presentation_state_id = state_id
	var feet_y: float = _get_asset_feet_position().y
	_presentation_state_id = previous_state
	return feet_y


func get_state_ground_offset_y_for_tests(state_id: StringName) -> float:
	var previous_state: StringName = _presentation_state_id
	_presentation_state_id = state_id
	var offset_y: float = _get_state_ground_offset_y()
	_presentation_state_id = previous_state
	return offset_y


func _draw() -> void:
	var texture: Texture2D = _get_current_texture()
	var source_rect: Rect2 = _get_current_source_rect()
	var asset_size: Vector2 = _get_asset_draw_size(source_rect.size)
	var feet: Vector2 = _get_asset_feet_position()
	var asset_rect := Rect2(
		feet - Vector2(asset_size.x * 0.5, asset_size.y),
		asset_size
	)
	if texture != null:
		_draw_asset_texture(texture, asset_rect, source_rect)
	if not _detached_death and not _detached_fall:
		_draw_health_bar(asset_rect)


func _get_asset_feet_position() -> Vector2:
	var feet := Vector2(0.0, _body_radius + 4.0) + asset_offset
	feet.y += _get_state_ground_offset_y()
	return feet


func _get_state_ground_offset_y() -> float:
	if _archetype_id != &"runner":
		return 0.0
	if _resolve_asset_state(_presentation_state_id) != &"idle":
		return 0.0
	return fast_idle_ground_offset_y
