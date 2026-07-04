class_name AnchorVisualController
extends Node2D

const CHAIN_TEXTURE: Texture2D = preload(
	"res://visual/tiles/tile_chain_base_01.png"
)
const CLAMP_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_clamp.png"
)
const WINCH_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_winch_01.png"
)
const ANCHOR_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_anchor.png"
)
const CHAIN_BACKING_WIDTH := 4.0
const CHAIN_BRIGHTEN_AMOUNT := 0.18

@export_group("Anchor Assets")
@export_range(0.05, 0.5, 0.01) var object_asset_scale := 0.16
@export_range(1.0, 2.0, 0.05) var clamp_scale_multiplier := 1.55
@export_range(8.0, 128.0, 1.0) var chain_tile_height := 26.0
@export_range(0.0, 0.9, 0.01) var chain_tile_overlap_ratio := 0.5
@export_range(0.0, 1.0, 0.01) var alpha_crop_threshold := 0.08
@export_range(1, 128, 1) var minimum_z_index := 18
@export var clamp_ground_offset := Vector2(0.0, 2.0)
@export var clamp_chain_connection_offset := Vector2(0.0, -17.0)
@export var stowed_chain_length := 20.0
@export var winch_vertical_offset := 0.0
@export_range(0.0, 30.0, 1.0) var winch_embed_depth := 5.0
@export var winch_chain_exit_offset := Vector2.ZERO

var _store: AnchorRuntimeStore
var _geometry: AnchorGeometry
var _balance: AnchorBalance
var _is_operator_available: Callable
var _is_simulation_active: Callable
var _warning_elapsed := 0.0
var _chain_source_rect: Rect2
var _clamp_source_rect: Rect2
var _winch_source_rect: Rect2
var _anchor_source_rect: Rect2


func _ready() -> void:
	z_as_relative = false
	z_index = maxi(z_index, minimum_z_index)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_chain_source_rect = TextureRegionLayout.get_alpha_bounds(
		CHAIN_TEXTURE,
		alpha_crop_threshold
	)
	_clamp_source_rect = TextureRegionLayout.get_alpha_bounds(
		CLAMP_TEXTURE,
		alpha_crop_threshold
	)
	_winch_source_rect = TextureRegionLayout.get_alpha_bounds(
		WINCH_TEXTURE,
		alpha_crop_threshold
	)
	_anchor_source_rect = TextureRegionLayout.get_alpha_bounds(
		ANCHOR_TEXTURE,
		alpha_crop_threshold
	)


func configure(
	store: AnchorRuntimeStore,
	geometry: AnchorGeometry,
	balance: AnchorBalance,
	is_operator_available: Callable,
	is_simulation_active: Callable
) -> void:
	_store = store
	_geometry = geometry
	_balance = balance
	_is_operator_available = is_operator_available
	_is_simulation_active = is_simulation_active


func _process(delta: float) -> void:
	if _is_simulation_active.is_valid() and bool(_is_simulation_active.call()):
		_warning_elapsed += maxf(0.0, delta)
	queue_redraw()


func _draw() -> void:
	if _store == null:
		return
	for anchor: AnchorRuntime in _store.get_all():
		_draw_anchor(anchor)
	_draw_winch_posts()


func get_winch_visual_bottom(anchor_id: int) -> Vector2:
	return _get_winch_bottom(anchor_id)


func get_winch_chain_exit(anchor_id: int) -> Vector2:
	var offset := winch_chain_exit_offset
	if _is_winch_mirrored(anchor_id):
		offset.x *= -1.0
	return _get_winch_bottom(anchor_id) + offset


func get_clamp_visual_scale() -> float:
	return object_asset_scale * clamp_scale_multiplier


func are_anchor_asset_regions_valid_for_tests() -> bool:
	return (
		_chain_source_rect.size.x > 0.0
		and _chain_source_rect.size.y > 0.0
		and _clamp_source_rect.size.x > 0.0
		and _clamp_source_rect.size.y > 0.0
		and _winch_source_rect.size.x > 0.0
		and _winch_source_rect.size.y > 0.0
		and _anchor_source_rect.size.x > 0.0
		and _anchor_source_rect.size.y > 0.0
	)


func _draw_winch_posts() -> void:
	for anchor_id: int in range(4):
		var side := (
			AnchorRuntime.Side.LEFT
			if anchor_id < 2
			else AnchorRuntime.Side.RIGHT
		)
		var mirrored := _is_winch_mirrored(anchor_id)
		_draw_winch(
			_get_winch_bottom(anchor_id),
			mirrored,
			bool(_is_operator_available.call(side))
		)


func _draw_winch(
	bottom: Vector2,
	mirrored: bool,
	operator_available: bool
) -> void:
	var tint := (
		Color.WHITE
		if operator_available
		else Color(0.52, 0.55, 0.58, 1.0)
	)
	var size := _winch_source_rect.size * object_asset_scale
	var rect := Rect2(Vector2(-size.x * 0.5, -size.y), size)
	var backing_center := bottom + Vector2(0.0, -size.y * 0.42)
	draw_circle(
		backing_center,
		maxf(8.0, size.x * 0.24),
		Color(0.08, 0.12, 0.18, 0.58)
	)
	var draw_scale := Vector2(-1.0, 1.0) if mirrored else Vector2.ONE
	draw_set_transform(bottom, 0.0, draw_scale)
	draw_texture_rect_region(WINCH_TEXTURE, rect, _winch_source_rect, tint)
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
			_draw_attached_anchor(
				anchor,
				start,
				_geometry.get_runtime_ground_point(anchor)
			)
		AnchorRuntime.State.RETURNING:
			_draw_returning_anchor(
				anchor,
				start,
				_geometry.get_runtime_ground_point(anchor)
			)


func _draw_stowed_anchor(anchor: AnchorRuntime, start: Vector2) -> void:
	var top := start + Vector2(0.0, stowed_chain_length)
	var tint := (
		Color.WHITE
		if bool(_is_operator_available.call(anchor.side))
		else Color(0.68, 0.7, 0.72, 1.0)
	)
	_draw_chain_links(start, top, tint)
	_draw_anchor_asset(top, tint)


func _draw_available_clamp(anchor: AnchorRuntime) -> void:
	if _geometry.get_current_installation_orb_id() < 0:
		return
	_draw_clamp(
		_geometry.get_current_silhouette_ground_point(anchor.anchor_id),
		_get_clamp_tint(anchor)
	)


func _draw_installing_anchor(anchor: AnchorRuntime, start: Vector2) -> void:
	var ground := anchor.target_ground_point
	var target := _get_clamp_connection_point(ground)
	var ratio := clampf(
		anchor.operation_progress / maxf(_balance.install_duration, 0.01),
		0.0,
		1.0
	)
	var top := start.lerp(target, ratio)
	var tint := Color(0.92, 0.82, 0.55, 1.0)
	_draw_clamp(ground, _get_clamp_tint(anchor))
	_draw_chain_links(start, top, tint)
	_draw_anchor_asset(top, tint)


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
		color = Color(1.0, 0.08, 0.04).lerp(
			Color(1.0, 0.65, 0.12),
			pulse
		)
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
	var target := _get_clamp_connection_point(ground)
	_draw_clamp(ground, Color.WHITE)
	_draw_chain_links(start, target, color)
	_draw_durability_meter(start.lerp(target, 0.5), ratio, color)


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
	var source := _get_clamp_connection_point(ground)
	var top := source.lerp(
		start + Vector2(0.0, stowed_chain_length),
		ratio
	)
	var color := Color(0.85, 0.76, 0.46)
	_draw_clamp(ground, Color.WHITE)
	_draw_chain_links(start, top, color)
	_draw_anchor_asset(top, color.lightened(0.12))


static func calculate_chain_link_positions(
	start: Vector2,
	finish: Vector2,
	spacing: float
) -> PackedVector2Array:
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
	var direction := segment / length
	var tile_size: Vector2 = TextureRegionLayout.fit_height(
		_chain_source_rect.size,
		chain_tile_height
	)
	var spacing: float = maxf(
		tile_size.y * (1.0 - chain_tile_overlap_ratio),
		1.0
	)
	var link_positions := calculate_chain_link_positions(
		start,
		finish,
		spacing
	)
	var link_rotation := direction.angle() - PI * 0.5
	var rect := Rect2(-tile_size * 0.5, tile_size)
	var visible_tint := tint.lightened(CHAIN_BRIGHTEN_AMOUNT)
	visible_tint.a = 1.0
	var backing := visible_tint
	backing.a = 0.4
	draw_line(start, finish, backing, CHAIN_BACKING_WIDTH, true)
	for link_position: Vector2 in link_positions:
		draw_set_transform(link_position, link_rotation, Vector2.ONE)
		draw_texture_rect_region(
			CHAIN_TEXTURE,
			rect,
			_chain_source_rect,
			visible_tint
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_anchor_asset(top: Vector2, tint: Color) -> void:
	var size := _anchor_source_rect.size * object_asset_scale
	var rect := Rect2(Vector2(-size.x * 0.5, 0.0), size)
	draw_set_transform(top, 0.0, Vector2.ONE)
	draw_texture_rect_region(ANCHOR_TEXTURE, rect, _anchor_source_rect, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_clamp(ground: Vector2, tint: Color) -> void:
	var size := _clamp_source_rect.size * get_clamp_visual_scale()
	var bottom := ground + clamp_ground_offset
	var marker_center := bottom + Vector2(0.0, -size.y * 0.34)
	var glow := Color(tint.r, tint.g, tint.b, minf(0.3, maxf(0.16, tint.a * 0.24)))
	draw_circle(marker_center, maxf(8.0, size.x * 0.25), glow)
	draw_arc(
		marker_center,
		maxf(9.0, size.x * 0.31),
		0.0,
		TAU,
		28,
		Color(0.85, 0.96, 1.0, 0.55),
		2.0,
		true
	)
	var rect := Rect2(bottom + Vector2(-size.x * 0.5, -size.y), size)
	draw_texture_rect_region(CLAMP_TEXTURE, rect, _clamp_source_rect, tint)


func _get_winch_bottom(anchor_id: int) -> Vector2:
	return Vector2(
		_geometry.get_platform_attachment_world(anchor_id).x,
		_geometry.get_platform_surface_world_y() + winch_embed_depth
	)


func _get_anchor_chain_start(anchor_id: int) -> Vector2:
	return get_winch_chain_exit(anchor_id)


func _is_winch_mirrored(anchor_id: int) -> bool:
	return anchor_id == 1 or anchor_id == 3


func _get_clamp_tint(anchor: AnchorRuntime) -> Color:
	if not bool(_is_operator_available.call(anchor.side)):
		return Color(0.48, 0.5, 0.53, 0.78)
	if anchor.state == AnchorRuntime.State.QUEUED:
		return Color(1.0, 0.82, 0.35, 0.92)
	if anchor.state == AnchorRuntime.State.INSTALLING:
		return Color(0.5, 0.88, 1.0, 0.96)
	return Color(0.52, 1.0, 0.65, 0.9)


func _get_clamp_connection_point(ground: Vector2) -> Vector2:
	return ground + clamp_chain_connection_offset


func _draw_durability_meter(
	center: Vector2,
	ratio: float,
	fill: Color
) -> void:
	var size := Vector2(32.0, 5.0)
	var rect := Rect2(center - size * 0.5, size)
	draw_rect(rect.grow(2.0), Color(0.08, 0.06, 0.05, 0.9), true)
	draw_rect(
		Rect2(rect.position, Vector2(size.x * ratio, size.y)),
		fill,
		true
	)
	draw_rect(rect, Color(1.0, 0.92, 0.72, 0.8), false, 1.0)
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-14.0, -7.0),
		"%d%%" % roundi(ratio * 100.0),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		10,
		Color.WHITE
	)


func _get_durability_ratio(anchor: AnchorRuntime) -> float:
	if _balance.rope_max_durability <= 0.0:
		return 0.0
	return clampf(
		anchor.rope_durability / _balance.rope_max_durability,
		0.0,
		1.0
	)
