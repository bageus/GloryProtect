class_name AnchorVisualControllerFasteningScaled
extends AnchorVisualControllerPolished

const FASTENING_CLAMP_SCALE_MULTIPLIER := 0.9
const WINCH_SIZE_MULTIPLIER := 1.1
const ELECTRIC_WINCH_SIZE_MULTIPLIER := 0.9


func configure_combat(
	store: AnchorRuntimeStore,
	geometry: AnchorGeometry,
	balance: AnchorBalance,
	is_operator_available: Callable,
	is_simulation_active: Callable,
	anchor_host: CombatAnchorHostSystem,
	combat_anchors: CombatAnchorSystem
) -> void:
	super.configure_combat(
		store,
		geometry,
		balance,
		is_operator_available,
		is_simulation_active,
		anchor_host,
		combat_anchors
	)
	var second_pair_enabled := Callable()
	if anchor_host != null:
		second_pair_enabled = Callable(
			anchor_host,
			"is_second_winch_pair_enabled"
		)
	configure(
		store,
		geometry,
		balance,
		is_operator_available,
		is_simulation_active,
		second_pair_enabled
	)


func get_winch_scale_multiplier_for_tests() -> float:
	return _get_runtime_winch_scale()


func get_winch_scale_multiplier_for_anchor_tests(anchor_id: int) -> float:
	return _get_runtime_winch_scale_for_anchor(anchor_id)


func get_electric_winch_size_multiplier_for_tests() -> float:
	return ELECTRIC_WINCH_SIZE_MULTIPLIER


func get_active_clamp_scale_multiplier_for_tests() -> float:
	return _get_active_clamp_scale_multiplier()


func get_active_clamp_unscaled_visual_size_for_tests() -> Vector2:
	return _get_active_clamp_unscaled_visual_size()


func get_active_clamp_visual_size_for_tests() -> Vector2:
	return (
		_get_active_clamp_unscaled_visual_size()
		* _get_active_clamp_scale_multiplier()
	)


func _draw_winch(
	anchor_id: int,
	bottom: Vector2,
	mirrored: bool,
	operator_available: bool
) -> void:
	var texture: Texture2D = _get_winch_texture(anchor_id)
	var source_rect: Rect2 = _get_winch_source_rect(anchor_id)
	if texture == null or not _is_rect_drawable(source_rect):
		texture = BASE_WINCH_TEXTURE
		source_rect = _get_texture_source_rect(BASE_WINCH_TEXTURE)
	var tint := Color.WHITE if operator_available else Color(0.52, 0.55, 0.58, 1.0)
	var scale_value: float = _get_runtime_winch_scale_for_anchor(anchor_id)
	if not _is_rect_drawable(source_rect):
		_draw_scaled_fallback_winch(bottom, tint, scale_value)
		return
	var size: Vector2 = (
		source_rect.size
		* object_asset_scale
		* scale_value
	)
	var rect := Rect2(Vector2(-size.x * 0.5, -size.y), size)
	var draw_scale := Vector2(-1.0, 1.0) if mirrored else Vector2.ONE
	draw_set_transform(bottom, 0.0, draw_scale)
	draw_texture_rect_region(texture, rect, source_rect, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _get_winch_draw_size(anchor_id: int) -> Vector2:
	var source_rect: Rect2 = _get_winch_source_rect(anchor_id)
	if not _is_rect_drawable(source_rect):
		source_rect = _get_texture_source_rect(BASE_WINCH_TEXTURE)
	var scale_value: float = _get_runtime_winch_scale_for_anchor(anchor_id)
	if not _is_rect_drawable(source_rect):
		return Vector2(58.0, 54.0) * scale_value
	return source_rect.size * object_asset_scale * scale_value


func _get_clamp_visual_rect(ground: Vector2) -> Rect2:
	var size := (
		_get_active_clamp_unscaled_visual_size()
		* _get_active_clamp_scale_multiplier()
	)
	var bottom := ground + clamp_ground_offset
	return Rect2(bottom + Vector2(-size.x * 0.5, -size.y), size)


func _draw_clamp_texture(
	ground: Vector2,
	texture: Texture2D,
	source_rect: Rect2,
	tint: Color
) -> void:
	var source_size: Vector2 = source_rect.size
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		source_size = Vector2(42.0, 34.0)
	var size := (
		source_size
		* get_clamp_visual_scale()
		* _get_active_clamp_scale_multiplier()
	)
	var bottom := ground + clamp_ground_offset
	var rect := Rect2(bottom + Vector2(-size.x * 0.5, -size.y), size)
	draw_texture_rect_region(texture, rect, source_rect, tint)


func _get_active_clamp_unscaled_visual_size() -> Vector2:
	var source_rect: Rect2 = _get_active_clamp_source_rect()
	var source_size: Vector2 = source_rect.size
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		source_size = Vector2(42.0, 34.0)
	return source_size * get_clamp_visual_scale()


func _get_active_clamp_scale_multiplier() -> float:
	var asset_id: StringName = _get_combat_clamp_asset_id()
	if asset_id in [&"fastening", &"turbo_fastening"]:
		return FASTENING_CLAMP_SCALE_MULTIPLIER
	return 1.0


func _get_runtime_winch_scale() -> float:
	return WINCH_SCALE_MULTIPLIER * WINCH_SIZE_MULTIPLIER


func _get_runtime_winch_scale_for_anchor(anchor_id: int) -> float:
	var scale_value: float = _get_runtime_winch_scale()
	if _get_combat_winch_asset_id(anchor_id) == &"specialization_2":
		scale_value *= ELECTRIC_WINCH_SIZE_MULTIPLIER
	return scale_value


func _draw_scaled_fallback_winch(
	center: Vector2,
	tint: Color,
	scale_value: float = -1.0
) -> void:
	if scale_value <= 0.0:
		scale_value = _get_runtime_winch_scale()
	draw_circle(center, 15.0 * scale_value, tint.darkened(0.25))
	draw_arc(
		center,
		15.0 * scale_value,
		0.0,
		TAU,
		32,
		tint.lightened(0.15),
		maxf(1.0, 3.0 * scale_value),
		true
	)
	draw_circle(center, 5.0 * scale_value, tint.darkened(0.4))
