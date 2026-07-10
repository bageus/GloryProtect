class_name AnchorVisualController
extends Node2D

const CHAIN_TEXTURE: Texture2D = preload(
	"res://visual/tiles/tile_chain_base_01.png"
)
const CLAMP_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_clamp.png"
)
const WINCH_BASE_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_winch_01.png"
)
const ANCHOR_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_anchor.png"
)
const CHAIN_BACKING_WIDTH := 4.0
const CHAIN_BRIGHTEN_AMOUNT := 0.18

@export_group("Anchor Assets")
@export_range(0.05, 0.5, 0.01) var object_asset_scale := 0.20
@export_range(0.2, 1.2, 0.01) var winch_asset_scale_multiplier := 0.70
@export_range(0.5, 2.0, 0.005) var clamp_scale_multiplier := 1.085
@export_range(8.0, 128.0, 1.0) var chain_tile_height := 28.0
@export_range(0.0, 0.9, 0.01) var chain_tile_overlap_ratio := 0.5
@export_range(0.0, 1.0, 0.01) var alpha_crop_threshold := 0.08
@export_range(1, 128, 1) var minimum_z_index := 80
@export var clamp_ground_offset := Vector2(0.0, 8.0)
@export var clamp_chain_connection_offset := Vector2(0.0, -6.0)
@export var anchor_chain_connection_offset := Vector2(0.0, 6.0)
@export var stowed_chain_length := 22.0
@export_range(0.0, 30.0, 1.0) var winch_embed_depth := 0.0
@export var winch_chain_exit_offset := Vector2(0.0, 4.0)
@export var draw_winch_posts := true

var _store: AnchorRuntimeStore
var _geometry: AnchorGeometry
var _balance: AnchorBalance
var _is_operator_available: Callable
var _is_simulation_active: Callable
var _is_second_winch_pair_enabled: Callable
var _warning_elapsed := 0.0
var _chain_source_rect: Rect2
var _clamp_source_rect: Rect2
var _anchor_source_rect: Rect2
var _source_rects: Dictionary = {}


func _ready() -> void:
	z_as_relative = false
	z_index = maxi(z_index, minimum_z_index)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_chain_source_rect = TextureRegionLayout.get_alpha_bounds(CHAIN_TEXTURE, alpha_crop_threshold)
	_clamp_source_rect = TextureRegionLayout.get_alpha_bounds(CLAMP_TEXTURE, alpha_crop_threshold)
	_anchor_source_rect = TextureRegionLayout.get_alpha_bounds(ANCHOR_TEXTURE, alpha_crop_threshold)
	_register_texture_source_rect(WINCH_BASE_TEXTURE)


func configure(
	store: AnchorRuntimeStore,
	geometry: AnchorGeometry,
	balance: AnchorBalance,
	is_operator_available: Callable,
	is_simulation_active: Callable,
	is_second_winch_pair_enabled: Callable = Callable()
) -> void:
	_store = store
	_geometry = geometry
	_balance = balance
	_is_operator_available = is_operator_available
	_is_simulation_active = is_simulation_active
	_is_second_winch_pair_enabled = is_second_winch_pair_enabled
	queue_redraw()


func _process(delta: float) -> void:
	if _is_simulation_active.is_valid() and bool(_is_simulation_active.call()):
		_warning_elapsed += maxf(0.0, delta)
	queue_redraw()


func _draw() -> void:
	if _store == null:
		return
	for anchor: AnchorRuntime in _store.get_all():
		if not _is_anchor_slot_visible(anchor.anchor_id):
			continue
		_draw_anchor(anchor)
	if draw_winch_posts:
		_draw_winch_posts()


func get_winch_visual_bottom(anchor_id: int) -> Vector2:
	return _get_winch_bottom(anchor_id)


func get_winch_chain_exit(anchor_id: int) -> Vector2:
	var offset := winch_chain_exit_offset
	if _is_winch_mirrored(anchor_id):
		offset.x *= -1.0
	return _get_winch_bottom(anchor_id) + offset


func get_winch_asset_id_for_tests(anchor_id: int = 0) -> StringName:
	return _get_winch_asset_id(anchor_id)


func get_clamp_visual_scale() -> float:
	return object_asset_scale * clamp_scale_multiplier


func get_anchor_visual_z_index_for_tests() -> int:
	return z_index


func get_visible_anchor_ids_for_tests() -> PackedInt32Array:
	return _get_visible_anchor_ids()


func is_winch_drawable_for_tests(anchor_id: int) -> bool:
	var texture: Texture2D = _get_winch_texture(anchor_id)
	var source_rect: Rect2 = _get_texture_source_rect(texture)
	if texture != null and _is_rect_drawable(source_rect):
		return true
	return _is_rect_drawable(_get_texture_source_rect(WINCH_BASE_TEXTURE))


func are_anchor_asset_regions_valid_for_tests() -> bool:
	return (
		_is_rect_drawable(_chain_source_rect)
		and _is_rect_drawable(_clamp_source_rect)
		and _is_rect_drawable(_anchor_source_rect)
		and is_winch_drawable_for_tests(0)
	)


func _draw_winch_posts() -> void:
	for anchor_id: int in _get_visible_anchor_ids():
		var side := AnchorRuntime.Side.LEFT if anchor_id < 2 else AnchorRuntime.Side.RIGHT
		_draw_winch(
			anchor_id,
			_get_winch_bottom(anchor_id),
			_is_winch_mirrored(anchor_id),
			bool(_is_operator_available.call(side))
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
		texture = WINCH_BASE_TEXTURE
		source_rect = _get_texture_source_rect(WINCH_BASE_TEXTURE)
	var tint := Color.WHITE if operator_available else Color(0.52, 0.55, 0.58, 1.0)
	var size := Vector2(58.0, 54.0) * winch_asset_scale_multiplier
	if _is_rect_drawable(source_rect):
		size = source_rect.size * object_asset_scale * winch_asset_scale_multiplier
	var pedestal_size := Vector2(maxf(24.0, size.x * 0.74), 9.0)
	var pedestal_rect := Rect2(bottom - Vector2(pedestal_size.x * 0.5, pedestal_size.y * 0.86), pedestal_size)
	draw_rect(pedestal_rect.grow(2.0), Color(0.02, 0.035, 0.055, 0.82), true)
	draw_rect(pedestal_rect, Color(0.16, 0.23, 0.32, 0.92), true)
	draw_rect(pedestal_rect, Color(0.72, 0.86, 1.0, 0.5), false, 1.2)
	var backing_center := bottom + Vector2(0.0, -size.y * 0.45)
	draw_circle(backing_center, maxf(10.0, size.x * 0.3), Color(0.02, 0.04, 0.07, 0.68))
	draw_arc(backing_center, maxf(11.0, size.x * 0.33), 0.0, TAU, 32, Color(0.72, 0.88, 1.0, 0.45), 1.8, true)
	if not _is_rect_drawable(source_rect):
		_draw_fallback_winch(backing_center, tint)
		return
	var rect := Rect2(Vector2(-size.x * 0.5, -size.y), size)
	var draw_scale := Vector2(-1.0, 1.0) if mirrored else Vector2.ONE
	draw_set_transform(bottom, 0.0, draw_scale)
	draw_texture_rect_region(texture, rect, source_rect, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_anchor(anchor: AnchorRuntime) -> void:
	var start := _get_anchor_chain_start(anchor.anchor_id)
	match anchor.state:
		AnchorRuntime.State.STOWED:
			_draw_stowed_anchor(anchor, start)
			_draw_available_clamp(anchor)
		AnchorRuntime.State.QUEUED:
			_draw_stowed_anchor(anchor, start)
			_draw_clamp(anchor.target_ground_point, _get_clamp_tint(anchor))
		AnchorRuntime.State.INSTALLING:
			_draw_installing_anchor(anchor, start)
		AnchorRuntime.State.ATTACHED, AnchorRuntime.State.OVERLOADED:
			_draw_attached_anchor(anchor, start, _geometry.get_runtime_ground_point(anchor))
		AnchorRuntime.State.RETURNING:
			_draw_returning_anchor(anchor, start, _geometry.get_runtime_ground_point(anchor))


func _draw_stowed_anchor(anchor: AnchorRuntime, start: Vector2) -> void:
	var anchor_top := start + Vector2(0.0, stowed_chain_length)
	var chain_finish := _get_anchor_chain_connection(anchor_top)
	var tint := Color.WHITE if bool(_is_operator_available.call(anchor.side)) else Color(0.68, 0.7, 0.72, 1.0)
	_draw_chain_links(start, chain_finish, tint)
	_draw_anchor_asset(anchor_top, tint)


func _draw_available_clamp(anchor: AnchorRuntime) -> void:
	if _geometry.get_current_installation_orb_id() < 0:
		return
	_draw_clamp(_geometry.get_current_silhouette_ground_point(anchor.anchor_id), _get_clamp_tint(anchor))


func _draw_installing_anchor(anchor: AnchorRuntime, start: Vector2) -> void:
	var ground := anchor.target_ground_point
	var target := _get_clamp_connection_point(ground)
	var ratio := clampf(anchor.operation_progress / maxf(_balance.install_duration, 0.01), 0.0, 1.0)
	var anchor_top := start.lerp(target - anchor_chain_connection_offset, ratio)
	var tint := Color(0.92, 0.82, 0.55, 1.0)
	_draw_clamp(ground, _get_clamp_tint(anchor))
	_draw_chain_links(start, _get_anchor_chain_connection(anchor_top), tint)
	_draw_anchor_asset(anchor_top, tint)


func _draw_attached_anchor(anchor: AnchorRuntime, start: Vector2, ground: Vector2) -> void:
	var ratio := _get_durability_ratio(anchor)
	var color := Color(0.92, 0.75, 0.36)
	if ratio <= _balance.rope_critical_ratio:
		var pulse := 0.5 + 0.5 * sin(_warning_elapsed * _balance.rope_warning_pulse_speed)
		color = Color(1.0, 0.08, 0.04).lerp(Color(1.0, 0.65, 0.12), pulse)
	elif ratio <= _balance.rope_damaged_ratio:
		color = Color(1.0, 0.42, 0.08)
	if anchor.state == AnchorRuntime.State.OVERLOADED:
		var overload_pulse := 0.5 + 0.5 * sin(_warning_elapsed * _balance.rope_warning_pulse_speed * 1.4)
		color = Color(1.0, 0.05, 0.03).lerp(Color(1.0, 0.35, 0.08), overload_pulse)
	var target := _get_clamp_connection_point(ground)
	_draw_clamp(ground, Color.WHITE)
	_draw_chain_links(start, target, color)
	_draw_durability_meter(start.lerp(target, 0.5), ratio, color)


func _draw_returning_anchor(anchor: AnchorRuntime, start: Vector2, ground: Vector2) -> void:
	var ratio := clampf(anchor.operation_progress / maxf(_balance.return_duration, 0.01), 0.0, 1.0)
	var source := _get_clamp_connection_point(ground)
	var anchor_top := (source - anchor_chain_connection_offset).lerp(start + Vector2(0.0, stowed_chain_length), ratio)
	var color := Color(0.85, 0.76, 0.46)
	_draw_clamp(ground, Color.WHITE)
	_draw_chain_links(start, _get_anchor_chain_connection(anchor_top), color)
	_draw_anchor_asset(anchor_top, color.lightened(0.12))


static func calculate_chain_link_positions(start: Vector2, finish: Vector2, spacing: float) -> PackedVector2Array:
	var positions := PackedVector2Array()
	var segment := finish - start
	var length := segment.length()
	if length <= 0.01:
		return positions
	var direction := segment / length
	var safe_spacing := maxf(spacing, 1.0)
	var count := maxi(2, ceili(length / safe_spacing) + 1)
	var step := length / float(count - 1)
	for index: int in range(count):
		positions.append(start + direction * step * float(index))
	return positions


func _draw_chain_links(start: Vector2, finish: Vector2, tint: Color) -> void:
	var segment := finish - start
	var length := segment.length()
	if length <= 0.01:
		return
	var visible_tint := tint.lightened(CHAIN_BRIGHTEN_AMOUNT)
	visible_tint.a = 1.0
	var backing := visible_tint
	backing.a = 0.4
	draw_line(start, finish, backing, CHAIN_BACKING_WIDTH, true)
	if not _is_rect_drawable(_chain_source_rect):
		_draw_fallback_chain(start, finish, visible_tint)
		return
	var direction := segment / length
	var tile_size: Vector2 = TextureRegionLayout.fit_height(_chain_source_rect.size, chain_tile_height)
	var spacing: float = maxf(tile_size.y * (1.0 - chain_tile_overlap_ratio), 1.0)
	var link_positions := calculate_chain_link_positions(start, finish, spacing)
	var link_rotation := direction.angle() - PI * 0.5
	var rect := Rect2(-tile_size * 0.5, tile_size)
	for link_position: Vector2 in link_positions:
		draw_set_transform(link_position, link_rotation, Vector2.ONE)
		draw_texture_rect_region(CHAIN_TEXTURE, rect, _chain_source_rect, visible_tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_anchor_asset(top: Vector2, tint: Color) -> void:
	if not _is_rect_drawable(_anchor_source_rect):
		_draw_fallback_anchor(top, tint)
		return
	var size := _anchor_source_rect.size * object_asset_scale
	var rect := Rect2(Vector2(-size.x * 0.5, 0.0), size)
	draw_set_transform(top, 0.0, Vector2.ONE)
	draw_texture_rect_region(ANCHOR_TEXTURE, rect, _anchor_source_rect, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_clamp(ground: Vector2, tint: Color) -> void:
	var source_size: Vector2 = _clamp_source_rect.size
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		source_size = Vector2(42.0, 34.0)
	var size := source_size * get_clamp_visual_scale()
	var bottom := ground + clamp_ground_offset
	var marker_center := bottom + Vector2(0.0, -size.y * 0.34)
	var glow := Color(tint.r, tint.g, tint.b, minf(0.3, maxf(0.16, tint.a * 0.24)))
	draw_circle(marker_center, maxf(8.0, size.x * 0.25), glow)
	draw_arc(marker_center, maxf(9.0, size.x * 0.31), 0.0, TAU, 28, Color(0.85, 0.96, 1.0, 0.55), 2.0, true)
	if not _is_rect_drawable(_clamp_source_rect):
		_draw_fallback_clamp(bottom, tint)
		return
	var rect := Rect2(bottom + Vector2(-size.x * 0.5, -size.y), size)
	draw_texture_rect_region(CLAMP_TEXTURE, rect, _clamp_source_rect, tint)


func _draw_fallback_winch(center: Vector2, tint: Color) -> void:
	draw_circle(center, 15.0 * winch_asset_scale_multiplier, tint.darkened(0.25))
	draw_arc(center, 15.0 * winch_asset_scale_multiplier, 0.0, TAU, 32, tint.lightened(0.15), 3.0, true)
	draw_circle(center, 5.0 * winch_asset_scale_multiplier, tint.darkened(0.4))


func _draw_fallback_chain(start: Vector2, finish: Vector2, tint: Color) -> void:
	var positions := calculate_chain_link_positions(start, finish, 10.0)
	for point: Vector2 in positions:
		draw_circle(point, 3.0, tint)


func _draw_fallback_anchor(top: Vector2, tint: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		top + Vector2(0.0, 14.0),
		top + Vector2(-7.0, 2.0),
		top + Vector2(7.0, 2.0),
	]), tint)
	draw_circle(top + Vector2(0.0, 2.0), 4.0, tint.lightened(0.2))


func _draw_fallback_clamp(bottom: Vector2, tint: Color) -> void:
	var rect := Rect2(bottom + Vector2(-12.0, -18.0), Vector2(24.0, 18.0))
	draw_rect(rect, tint, true)
	draw_rect(rect, Color(0.85, 0.96, 1.0, 0.65), false, 2.0)


func _draw_durability_meter(center: Vector2, ratio: float, color: Color) -> void:
	var width := 32.0
	var height := 4.0
	var background := Rect2(center + Vector2(-width * 0.5, 10.0), Vector2(width, height))
	draw_rect(background, Color(0.02, 0.03, 0.04, 0.65), true)
	draw_rect(Rect2(background.position, Vector2(width * clampf(ratio, 0.0, 1.0), height)), color, true)


func _get_visible_anchor_ids() -> PackedInt32Array:
	if _is_second_pair_enabled():
		return PackedInt32Array([0, 1, 2, 3])
	return PackedInt32Array([0, 3])


func _is_anchor_slot_visible(anchor_id: int) -> bool:
	if _is_second_pair_enabled():
		return anchor_id >= 0 and anchor_id <= 3
	return anchor_id == 0 or anchor_id == 3


func _is_second_pair_enabled() -> bool:
	return (
		_is_second_winch_pair_enabled.is_valid()
		and bool(_is_second_winch_pair_enabled.call())
	)


func _get_anchor_chain_connection(anchor_top: Vector2) -> Vector2:
	return anchor_top + anchor_chain_connection_offset


func _get_clamp_connection_point(ground: Vector2) -> Vector2:
	return ground + clamp_chain_connection_offset


func _get_clamp_tint(anchor: AnchorRuntime) -> Color:
	if anchor.state == AnchorRuntime.State.QUEUED:
		return Color(0.92, 0.82, 0.55, 1.0)
	if anchor.state == AnchorRuntime.State.INSTALLING:
		return Color(0.98, 0.9, 0.55, 1.0)
	return Color.WHITE


func _get_durability_ratio(anchor: AnchorRuntime) -> float:
	if _balance == null or _balance.rope_max_durability <= 0.0:
		return 1.0
	if anchor.rope_durability <= 0.0:
		return 1.0
	return clampf(anchor.rope_durability / _balance.rope_max_durability, 0.0, 1.0)


func _get_winch_texture(_anchor_id: int) -> Texture2D:
	return WINCH_BASE_TEXTURE


func _get_winch_source_rect(anchor_id: int) -> Rect2:
	return _get_texture_source_rect(_get_winch_texture(anchor_id))


func _get_winch_asset_id(_anchor_id: int) -> StringName:
	return &"base"


func _is_winch_mirrored(anchor_id: int) -> bool:
	return anchor_id >= 2


func _get_texture_source_rect(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()
	if _source_rects.has(texture):
		return _source_rects[texture]
	return Rect2(Vector2.ZERO, texture.get_size())


func _register_texture_source_rect(texture: Texture2D) -> void:
	if texture == null:
		return
	_source_rects[texture] = TextureRegionLayout.get_alpha_bounds(texture, alpha_crop_threshold)


func _is_rect_drawable(rect: Rect2) -> bool:
	return rect.size.x > 0.0 and rect.size.y > 0.0


func _get_winch_bottom(anchor_id: int) -> Vector2:
	return Vector2(
		_geometry.get_platform_attachment_world(anchor_id).x,
		_geometry.get_platform_surface_world_y() + winch_embed_depth
	)


func _get_anchor_chain_start(anchor_id: int) -> Vector2:
	return get_winch_chain_exit(anchor_id)
