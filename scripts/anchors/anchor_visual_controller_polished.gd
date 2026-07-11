class_name AnchorVisualControllerPolished
extends CombatAnchorVisualController

const BASE_ANCHOR_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_anchor.png"
)
const MAGNET_ANCHOR_TEXTURE_POLISHED: Texture2D = preload(
	"res://visual/objects/asset_anchor_02.png"
)
const BASE_CLAMP_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_clamp.png"
)
const FASTENING_CLAMP_TEXTURE_POLISHED: Texture2D = preload(
	"res://visual/objects/asset_clamp_02.png"
)
const TURBO_CLAMP_TEXTURE_POLISHED: Texture2D = preload(
	"res://visual/objects/asset_clamp_03.png"
)
const BASE_WINCH_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_winch_01.png"
)
const STRONG_WINCH_TEXTURE_POLISHED: Texture2D = preload(
	"res://visual/objects/asset_winch_02.png"
)
const ELECTRIC_WINCH_TEXTURE_POLISHED: Texture2D = preload(
	"res://visual/objects/asset_winch_03.png"
)
const TRAP_WINCH_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_winch_04.png"
)

# Another visible 15% increase from the previously rendered 0.483 scale.
# No platform-cell width is used by the runtime draw path.
const WINCH_SCALE_MULTIPLIER := 0.55545
const ANCHOR_CHAIN_ATTACH_DEPTH := 14.0
const GROUND_CLAMP_OFFSET := Vector2(0.0, 2.0)
const STOWED_CHAIN_LENGTH := 38.0
const STOWED_ANCHOR_PROTRUSION := 5.0
const CHAIN_SOCKET_OVERLAP_RATIO := 1.0 / 3.0


func _init() -> void:
	clamp_ground_offset = GROUND_CLAMP_OFFSET


func _ready() -> void:
	stowed_chain_length = STOWED_CHAIN_LENGTH
	super._ready()
	_clamp_source_rect = _calculate_alpha_bounds(BASE_CLAMP_TEXTURE)
	_anchor_source_rect = _calculate_alpha_bounds(BASE_ANCHOR_TEXTURE)
	var cropped_textures: Array[Texture2D] = [
		BASE_ANCHOR_TEXTURE,
		BASE_CLAMP_TEXTURE,
		BASE_WINCH_TEXTURE,
		STRONG_WINCH_TEXTURE_POLISHED,
		ELECTRIC_WINCH_TEXTURE_POLISHED,
		TRAP_WINCH_TEXTURE,
		FASTENING_CLAMP_TEXTURE_POLISHED,
		TURBO_CLAMP_TEXTURE_POLISHED,
		MAGNET_ANCHOR_TEXTURE_POLISHED,
	]
	for texture: Texture2D in cropped_textures:
		_register_alpha_cropped_texture(texture)


func _draw() -> void:
	if _store == null:
		return
	if draw_winch_posts:
		_draw_winch_posts()
	for anchor: AnchorRuntime in _store.get_all():
		if not _is_anchor_slot_visible(anchor.anchor_id):
			continue
		_draw_anchor(anchor)
	_draw_trap_bursts()


func get_winch_scale_multiplier_for_tests() -> float:
	return WINCH_SCALE_MULTIPLIER


func get_anchor_chain_attach_depth_for_tests() -> float:
	return ANCHOR_CHAIN_ATTACH_DEPTH


func get_chain_socket_overlap_ratio_for_tests() -> float:
	return CHAIN_SOCKET_OVERLAP_RATIO


func get_chain_socket_overlap_depth_for_tests() -> float:
	return _get_chain_tile_draw_height() * CHAIN_SOCKET_OVERLAP_RATIO


func get_chain_socket_segment_for_tests(
	start: Vector2,
	finish: Vector2
) -> PackedVector2Array:
	return _get_socket_fitted_chain_endpoints(start, finish)


func get_clamp_connection_point_for_tests(ground: Vector2) -> Vector2:
	return _get_clamp_connection_point(ground)


func get_clamp_chain_socket_for_tests(ground: Vector2) -> Vector2:
	return _get_clamp_chain_socket(ground)


func get_anchor_chain_socket_for_tests(draw_top: Vector2) -> Vector2:
	return _get_anchor_chain_socket(draw_top)


func get_ground_clamp_bottom_for_tests(ground: Vector2) -> Vector2:
	return ground + clamp_ground_offset


func get_winch_visual_size_for_tests(anchor_id: int) -> Vector2:
	return _get_winch_draw_size(anchor_id)


func get_trap_winch_source_rect_for_tests() -> Rect2:
	return _get_texture_source_rect(TRAP_WINCH_TEXTURE)


func get_base_anchor_source_rect_for_tests() -> Rect2:
	return _anchor_source_rect


func get_base_clamp_source_rect_for_tests() -> Rect2:
	return _clamp_source_rect


func get_registered_base_anchor_source_rect_for_tests() -> Rect2:
	return _get_texture_source_rect(BASE_ANCHOR_TEXTURE)


func get_registered_base_clamp_source_rect_for_tests() -> Rect2:
	return _get_texture_source_rect(BASE_CLAMP_TEXTURE)


func get_ground_clamp_rect_for_tests(ground: Vector2) -> Rect2:
	return _get_clamp_visual_rect(ground)


func get_stowed_anchor_draw_top_for_tests(anchor_id: int) -> Vector2:
	return _get_stowed_anchor_draw_top(anchor_id)


func get_stowed_anchor_rect_for_tests(anchor_id: int) -> Rect2:
	return _get_anchor_visual_rect(_get_stowed_anchor_draw_top(anchor_id))


func get_winch_chain_exit(anchor_id: int) -> Vector2:
	# The chain is horizontally centered and enters through the visible bottom edge.
	return _get_winch_bottom(anchor_id)


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
	if not _is_rect_drawable(source_rect):
		_draw_scaled_fallback_winch(bottom, tint)
		return
	var size: Vector2 = source_rect.size * object_asset_scale * WINCH_SCALE_MULTIPLIER
	var rect := Rect2(Vector2(-size.x * 0.5, -size.y), size)
	var draw_scale := Vector2(-1.0, 1.0) if mirrored else Vector2.ONE
	draw_set_transform(bottom, 0.0, draw_scale)
	draw_texture_rect_region(texture, rect, source_rect, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _get_winch_draw_size(anchor_id: int) -> Vector2:
	var source_rect: Rect2 = _get_winch_source_rect(anchor_id)
	if not _is_rect_drawable(source_rect):
		source_rect = _get_texture_source_rect(BASE_WINCH_TEXTURE)
	if not _is_rect_drawable(source_rect):
		return Vector2(58.0, 54.0) * WINCH_SCALE_MULTIPLIER
	return source_rect.size * object_asset_scale * WINCH_SCALE_MULTIPLIER


func _get_winch_texture(anchor_id: int) -> Texture2D:
	match _get_combat_winch_asset_id(anchor_id):
		&"strong":
			return STRONG_WINCH_TEXTURE_POLISHED
		&"specialization_2":
			return ELECTRIC_WINCH_TEXTURE_POLISHED
		&"trap":
			return TRAP_WINCH_TEXTURE
		_:
			return BASE_WINCH_TEXTURE


func _get_combat_winch_asset_id(anchor_id: int) -> StringName:
	if (
		_combat_anchors != null
		and _combat_anchors.upgrades.specialization_id == CombatAnchorUpgradeRuntime.TRAP
	):
		return &"trap"
	return super._get_combat_winch_asset_id(anchor_id)


func _draw_stowed_anchor(anchor: AnchorRuntime, start: Vector2) -> void:
	var draw_top := _get_stowed_anchor_draw_top(anchor.anchor_id)
	var socket := _get_anchor_chain_socket(draw_top)
	var tint := Color.WHITE if bool(_is_operator_available.call(anchor.side)) else Color(0.68, 0.7, 0.72, 1.0)
	_draw_anchor_asset(draw_top, tint)
	_draw_socket_fitted_chain(
		start,
		socket,
		tint,
		Color(1.0, 0.95, 0.72, 1.0)
	)


func _draw_installing_anchor(anchor: AnchorRuntime, start: Vector2) -> void:
	var ground := anchor.target_ground_point
	var ratio := clampf(
		anchor.operation_progress / maxf(_balance.install_duration, 0.01),
		0.0,
		1.0
	)
	var stowed_top := _get_stowed_anchor_draw_top(anchor.anchor_id)
	var installed_top := _get_anchor_draw_top_above_clamp(ground)
	var draw_top := stowed_top.lerp(installed_top, ratio)
	var socket := _get_anchor_chain_socket(draw_top)
	var tint := Color(0.92, 0.82, 0.55, 1.0)
	_draw_clamp(ground, _get_clamp_tint(anchor))
	_draw_anchor_asset(draw_top, tint)
	_draw_socket_fitted_chain(
		start,
		socket,
		tint,
		Color(1.0, 0.93, 0.62, 1.0)
	)


func _draw_attached_anchor(
	anchor: AnchorRuntime,
	start: Vector2,
	ground: Vector2
) -> void:
	var ratio := _get_durability_ratio(anchor)
	var color := Color(0.92, 0.75, 0.36)
	if ratio <= _balance.rope_critical_ratio:
		var pulse := 0.5 + 0.5 * sin(
			_warning_elapsed * _balance.rope_warning_pulse_speed
		)
		color = Color(1.0, 0.08, 0.04).lerp(Color(1.0, 0.65, 0.12), pulse)
	elif ratio <= _balance.rope_damaged_ratio:
		color = Color(1.0, 0.42, 0.08)
	if anchor.state == AnchorRuntime.State.OVERLOADED:
		var overload_pulse := 0.5 + 0.5 * sin(
			_warning_elapsed * _balance.rope_warning_pulse_speed * 1.4
		)
		color = Color(1.0, 0.05, 0.03).lerp(
			Color(1.0, 0.35, 0.08),
			overload_pulse
		)
	_draw_clamp(ground, Color.WHITE)
	var socket := _get_clamp_chain_socket(ground)
	if _uses_turbo_fastening_assets():
		var anchor_top := _get_anchor_draw_top_above_clamp(ground)
		_draw_anchor_asset(anchor_top, Color.WHITE)
		socket = _get_anchor_chain_socket(anchor_top)
	_draw_socket_fitted_chain(
		start,
		socket,
		color,
		Color(1.0, 0.88, 0.48, 1.0)
	)
	_draw_durability_meter(start.lerp(socket, 0.5), ratio, color)
	if is_electric_visual_active(anchor.anchor_id):
		_draw_electric_arcs(start, socket, anchor.anchor_id)


func _draw_returning_anchor(
	anchor: AnchorRuntime,
	start: Vector2,
	ground: Vector2
) -> void:
	var ratio := clampf(
		anchor.operation_progress / maxf(_balance.return_duration, 0.01),
		0.0,
		1.0
	)
	var installed_top := _get_anchor_draw_top_above_clamp(ground)
	var stowed_top := _get_stowed_anchor_draw_top(anchor.anchor_id)
	var draw_top := installed_top.lerp(stowed_top, ratio)
	var socket := _get_anchor_chain_socket(draw_top)
	var color := Color(0.85, 0.76, 0.46)
	_draw_clamp(ground, Color.WHITE)
	_draw_anchor_asset(draw_top, color.lightened(0.12))
	_draw_socket_fitted_chain(
		start,
		socket,
		color,
		Color(0.98, 0.86, 0.52, 1.0)
	)


func _draw_socket_fitted_chain(
	start: Vector2,
	finish: Vector2,
	tint: Color,
	reinforced_tint: Color
) -> void:
	var endpoints: PackedVector2Array = _get_socket_fitted_chain_endpoints(
		start,
		finish
	)
	if endpoints.size() != 2:
		return
	_draw_chain_links(endpoints[0], endpoints[1], tint)
	if is_reinforced_chain_visual_active():
		_draw_reinforced_chain_overlay(
			endpoints[0],
			endpoints[1],
			reinforced_tint
		)


func _get_socket_fitted_chain_endpoints(
	start: Vector2,
	finish: Vector2
) -> PackedVector2Array:
	var segment := finish - start
	var length := segment.length()
	if length <= 0.01:
		return PackedVector2Array()
	var direction := segment / length
	var tile_height: float = _get_chain_tile_draw_height()
	var overlap_depth := tile_height * CHAIN_SOCKET_OVERLAP_RATIO
	var center_inset := maxf(tile_height * 0.5 - overlap_depth, 0.0)
	var safe_inset := minf(center_inset, length * 0.45)
	return PackedVector2Array([
		start + direction * safe_inset,
		finish - direction * safe_inset,
	])


func _get_chain_tile_draw_height() -> float:
	if not _is_rect_drawable(_chain_source_rect):
		return chain_tile_height
	return TextureRegionLayout.fit_height(
		_chain_source_rect.size,
		chain_tile_height
	).y


func _get_stowed_anchor_draw_top(anchor_id: int) -> Vector2:
	var anchor_size := _get_active_anchor_visual_size()
	var desired_bottom_y := (
		_get_platform_bottom_y(anchor_id) + STOWED_ANCHOR_PROTRUSION
	)
	return Vector2(
		_get_winch_bottom(anchor_id).x,
		desired_bottom_y - anchor_size.y + ANCHOR_CHAIN_ATTACH_DEPTH
	)


func _get_platform_bottom_y(anchor_id: int) -> float:
	var surface_y := _get_winch_bottom(anchor_id).y
	if _geometry == null or _balance == null:
		return surface_y + 58.0
	var attachment_y := _geometry.get_platform_attachment_world(anchor_id).y
	var denominator := _balance.platform_attachment_y_factor + 0.5
	if absf(denominator) <= 0.001:
		return surface_y + 58.0
	var platform_height := (attachment_y - surface_y) / denominator
	return surface_y + maxf(platform_height, 0.0)


func _get_anchor_draw_top_above_clamp(ground: Vector2) -> Vector2:
	var clamp_rect := _get_clamp_visual_rect(ground)
	var anchor_size := _get_active_anchor_visual_size()
	return Vector2(
		clamp_rect.position.x + clamp_rect.size.x * 0.5,
		clamp_rect.position.y - anchor_size.y + ANCHOR_CHAIN_ATTACH_DEPTH
	)


func _get_anchor_chain_socket(draw_top: Vector2) -> Vector2:
	var rect := _get_anchor_visual_rect(draw_top)
	return Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y)


func _get_clamp_chain_socket(ground: Vector2) -> Vector2:
	var rect := _get_clamp_visual_rect(ground)
	return Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y)


func _get_anchor_visual_rect(draw_top: Vector2) -> Rect2:
	var size := _get_active_anchor_visual_size()
	return Rect2(
		draw_top + Vector2(-size.x * 0.5, -ANCHOR_CHAIN_ATTACH_DEPTH),
		size
	)


func _get_clamp_visual_rect(ground: Vector2) -> Rect2:
	var source_rect := _get_active_clamp_source_rect()
	var source_size: Vector2 = source_rect.size
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		source_size = Vector2(42.0, 34.0)
	var size := source_size * get_clamp_visual_scale()
	var bottom := ground + clamp_ground_offset
	return Rect2(bottom + Vector2(-size.x * 0.5, -size.y), size)


func _get_active_anchor_visual_size() -> Vector2:
	var source_rect := _get_active_anchor_source_rect()
	if not _is_rect_drawable(source_rect):
		return Vector2(42.0, 50.0)
	return source_rect.size * object_asset_scale


func _get_active_anchor_source_rect() -> Rect2:
	var texture: Texture2D = _get_combat_anchor_texture()
	var source_rect := _get_texture_source_rect(texture)
	if _is_rect_drawable(source_rect):
		return source_rect
	return _anchor_source_rect


func _get_active_clamp_source_rect() -> Rect2:
	var texture: Texture2D = _get_combat_clamp_texture()
	var source_rect := _get_texture_source_rect(texture)
	if _is_rect_drawable(source_rect):
		return source_rect
	return _clamp_source_rect


func _draw_anchor_texture_at_top(
	top: Vector2,
	texture: Texture2D,
	source_rect: Rect2,
	tint: Color
) -> void:
	var size := source_rect.size * object_asset_scale
	var rect := Rect2(
		Vector2(-size.x * 0.5, -ANCHOR_CHAIN_ATTACH_DEPTH),
		size
	)
	draw_set_transform(top, 0.0, Vector2.ONE)
	draw_texture_rect_region(texture, rect, source_rect, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_clamp_texture(
	ground: Vector2,
	texture: Texture2D,
	source_rect: Rect2,
	tint: Color
) -> void:
	var source_size: Vector2 = source_rect.size
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		source_size = Vector2(42.0, 34.0)
	var size := source_size * get_clamp_visual_scale()
	var bottom := ground + clamp_ground_offset
	var rect := Rect2(bottom + Vector2(-size.x * 0.5, -size.y), size)
	draw_texture_rect_region(texture, rect, source_rect, tint)


func _get_clamp_connection_point(ground: Vector2) -> Vector2:
	return ground + clamp_ground_offset + clamp_chain_connection_offset


func _register_alpha_cropped_texture(texture: Texture2D) -> void:
	if texture == null:
		return
	_source_rects[texture] = _calculate_alpha_bounds(texture)


func _calculate_alpha_bounds(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return Rect2(Vector2.ZERO, texture.get_size())
	var used_rect: Rect2i = image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return Rect2(Vector2.ZERO, texture.get_size())
	var minimum := Vector2i(
		used_rect.position.x + used_rect.size.x,
		used_rect.position.y + used_rect.size.y
	)
	var maximum := Vector2i(-1, -1)
	var end_x: int = used_rect.position.x + used_rect.size.x
	var end_y: int = used_rect.position.y + used_rect.size.y
	for y: int in range(used_rect.position.y, end_y):
		for x: int in range(used_rect.position.x, end_x):
			if image.get_pixel(x, y).a <= alpha_crop_threshold:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2(Vector2.ZERO, texture.get_size())
	return Rect2(
		Vector2(minimum),
		Vector2(maximum - minimum + Vector2i.ONE)
	)


func _draw_scaled_fallback_winch(center: Vector2, tint: Color) -> void:
	draw_circle(
		center,
		15.0 * WINCH_SCALE_MULTIPLIER,
		tint.darkened(0.25)
	)
	draw_arc(
		center,
		15.0 * WINCH_SCALE_MULTIPLIER,
		0.0,
		TAU,
		32,
		tint.lightened(0.15),
		maxf(1.0, 3.0 * WINCH_SCALE_MULTIPLIER),
		true
	)
	draw_circle(
		center,
		5.0 * WINCH_SCALE_MULTIPLIER,
		tint.darkened(0.4)
	)
