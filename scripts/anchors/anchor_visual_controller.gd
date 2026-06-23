class_name AnchorVisualController
extends Node2D

const CHAIN_TEXTURE_PATH: String = "res://visual/tiles/tile_chain_base_01.png"
const CLAMP_TEXTURE_PATH: String = "res://visual/objects/asset_object_clamp.png"
const WINCH_TEXTURE_PATH: String = "res://visual/objects/asset_object_winch_post.png"
const ANCHOR_TEXTURE_PATH: String = "res://visual/objects/asset_object_anchor.png"
const CHAIN_BACKING_WIDTH := 7.0
const CHAIN_BRIGHTEN_AMOUNT := 0.18

@export_group("Anchor Assets")
@export_range(0.05, 0.5, 0.01) var object_asset_scale := 0.24
@export_range(8.0, 128.0, 1.0) var chain_tile_height := 46.0
@export_range(0.0, 0.9, 0.01) var chain_tile_overlap_ratio := 0.5
@export_range(0.0, 1.0, 0.01) var alpha_crop_threshold := 0.08
@export var clamp_ground_offset := Vector2(0.0, 4.0)
@export var clamp_chain_connection_offset := Vector2(0.0, -34.0)
@export var stowed_chain_length := 40.0
@export var winch_vertical_offset := -56.0
@export var winch_chain_exit_offset := Vector2(0.0, 24.0)

var _store: AnchorRuntimeStore
var _geometry: AnchorGeometry
var _balance: AnchorBalance
var _is_operator_available: Callable
var _is_simulation_active: Callable
var _warning_elapsed := 0.0
var _chain_texture: Texture2D
var _clamp_texture: Texture2D
var _winch_texture: Texture2D
var _anchor_texture: Texture2D
var _chain_source_rect: Rect2
var _clamp_source_rect: Rect2
var _winch_source_rect: Rect2
var _anchor_source_rect: Rect2


func _ready() -> void:
	z_index = 2
	_chain_texture = _load_optional_texture(CHAIN_TEXTURE_PATH)
	_clamp_texture = _load_optional_texture(CLAMP_TEXTURE_PATH)
	_winch_texture = _load_optional_texture(WINCH_TEXTURE_PATH)
	_anchor_texture = _load_optional_texture(ANCHOR_TEXTURE_PATH)
	if _chain_texture != null:
		_chain_source_rect = TextureRegionLayout.get_alpha_bounds(
			_chain_texture,
			alpha_crop_threshold
		)
	if _clamp_texture != null:
		_clamp_source_rect = TextureRegionLayout.get_alpha_bounds(
			_clamp_texture,
			alpha_crop_threshold
		)
	if _winch_texture != null:
		_winch_source_rect = TextureRegionLayout.get_alpha_bounds(
			_winch_texture,
			alpha_crop_threshold
		)
	if _anchor_texture != null:
		_anchor_source_rect = TextureRegionLayout.get_alpha_bounds(
			_anchor_texture,
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


func _draw_winch_posts() -> void:
	for anchor_id: int in range(4):
		var side := (
			AnchorRuntime.Side.LEFT
			if anchor_id < 2
			else AnchorRuntime.Side.RIGHT
		)
		var mirrored := anchor_id == 1 or anchor_id == 3
		_draw_winch(
			_get_winch_center(anchor_id),
			mirrored,
			bool(_is_operator_available.call(side))
		)


func _draw_winch(
	center: Vector2,
	mirrored: bool,
	operator_available: bool
) -> void:
	var tint := (
		Color.WHITE
		if operator_available
		else Color(0.52, 0.55, 0.58, 1.0)
	)
	var mirror_scale := Vector2(-1.0, 1.0) if mirrored else Vector2.ONE
	if _winch_texture != null:
		var size := _winch_source_rect.size * object_asset_scale
		var rect := Rect2(-size * 0.5, size)
		draw_set_transform(center, 0.0, mirror_scale)
		draw_texture_rect_region(_winch_texture, rect, _winch_source_rect, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	_draw_procedural_winch(center, tint)


func _draw_procedural_winch(center: Vector2, tint: Color) -> void:
	var body_rect := Rect2(center + Vector2(-18.0, -14.0), Vector2(36.0, 28.0))
	draw_rect(body_rect, Color(0.12, 0.18, 0.24, tint.a), true)
	draw_rect(body_rect, tint, false, 2.0)
	draw_circle(center, 9.0, Color(0.26, 0.38, 0.48, tint.a))
	draw_arc(center, 9.0, 0.0, TAU, 20, tint, 2.0)
	draw_line(center + Vector2(0.0, 9.0), center + Vector2(0.0, 24.0), tint, 3.0)


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


func _draw_chain_links(start: Vector2, finish: Vector2, tint: Color) -> void:
	if _chain_texture == null:
		return
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
	var count := maxi(1, ceili(length / spacing))
	var step := length / float(count)
	var link_rotation := direction.angle() - PI * 0.5
	var rect := Rect2(-tile_size * 0.5, tile_size)
	var visible_tint := tint.lightened(CHAIN_BRIGHTEN_AMOUNT)
	visible_tint.a = 1.0
	var backing := visible_tint
	backing.a = 0.4
	draw_line(start, finish, backing, CHAIN_BACKING_WIDTH, true)
	for index: int in range(count):
		var link_position := start + direction * (step * (float(index) + 0.5))
		draw_set_transform(link_position, link_rotation, Vector2.ONE)
		draw_texture_rect_region(
			_chain_texture,
			rect,
			_chain_source_rect,
			visible_tint
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_anchor_asset(top: Vector2, tint: Color) -> void:
	if _anchor_texture != null:
		var size := _anchor_source_rect.size * object_asset_scale
		var rect := Rect2(Vector2(-size.x * 0.5, 0.0), size)
		draw_set_transform(top, 0.0, Vector2.ONE)
		draw_texture_rect_region(_anchor_texture, rect, _anchor_source_rect, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var anchor_center := top + Vector2(0.0, 15.0)
	draw_line(top, anchor_center, tint, 4.0)
	draw_circle(anchor_center, 4.0, tint)
	draw_arc(anchor_center, 13.0, 0.15 * PI, 0.85 * PI, 18, tint, 4.0)
	draw_line(anchor_center + Vector2(-13.0, 6.0), anchor_center + Vector2(-18.0, 1.0), tint, 4.0)
	draw_line(anchor_center + Vector2(13.0, 6.0), anchor_center + Vector2(18.0, 1.0), tint, 4.0)


func _draw_clamp(ground: Vector2, tint: Color) -> void:
	if _clamp_texture != null:
		var size := _clamp_source_rect.size * object_asset_scale
		var bottom := ground + clamp_ground_offset
		var rect := Rect2(bottom + Vector2(-size.x * 0.5, -size.y), size)
		draw_texture_rect_region(_clamp_texture, rect, _clamp_source_rect, tint)
		return
	var bottom := ground + clamp_ground_offset
	var base_rect := Rect2(bottom + Vector2(-16.0, -8.0), Vector2(32.0, 8.0))
	draw_rect(base_rect, Color(0.12, 0.16, 0.2, tint.a), true)
	draw_rect(base_rect, tint, false, 2.0)
	draw_line(bottom + Vector2(-8.0, -8.0), bottom + Vector2(-3.0, -24.0), tint, 4.0)
	draw_line(bottom + Vector2(8.0, -8.0), bottom + Vector2(3.0, -24.0), tint, 4.0)


func _get_winch_center(anchor_id: int) -> Vector2:
	return (
		_geometry.get_platform_attachment_world(anchor_id)
		+ Vector2(0.0, winch_vertical_offset)
	)


func _get_anchor_chain_start(anchor_id: int) -> Vector2:
	return _get_winch_center(anchor_id) + winch_chain_exit_offset


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
	var size := Vector2(44.0, 6.0)
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
		center + Vector2(-16.0, -8.0),
		"%d%%" % roundi(ratio * 100.0),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		12,
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


func _load_optional_texture(resource_path: String) -> Texture2D:
	if not ResourceLoader.exists(resource_path):
		return null
	return ResourceLoader.load(resource_path) as Texture2D
