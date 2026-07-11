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

# The widest trap winch remains inside one 40 px platform cell at this scale.
const WINCH_SCALE_MULTIPLIER := 0.42
const ANCHOR_CHAIN_ATTACH_DEPTH := 14.0
const GROUND_CLAMP_OFFSET := Vector2(0.0, 2.0)
const WINCH_CHAIN_EXIT_OFFSET := Vector2(0.0, -2.0)


func _init() -> void:
	clamp_ground_offset = GROUND_CLAMP_OFFSET
	winch_chain_exit_offset = WINCH_CHAIN_EXIT_OFFSET


func _ready() -> void:
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


func get_winch_scale_multiplier_for_tests() -> float:
	return WINCH_SCALE_MULTIPLIER


func get_anchor_chain_attach_depth_for_tests() -> float:
	return ANCHOR_CHAIN_ATTACH_DEPTH


func get_clamp_connection_point_for_tests(ground: Vector2) -> Vector2:
	return _get_clamp_connection_point(ground)


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
	var source_rect: Rect2 = get_registered_base_clamp_source_rect_for_tests()
	var size: Vector2 = source_rect.size * get_clamp_visual_scale()
	var bottom: Vector2 = get_ground_clamp_bottom_for_tests(ground)
	return Rect2(bottom + Vector2(-size.x * 0.5, -size.y), size)


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
