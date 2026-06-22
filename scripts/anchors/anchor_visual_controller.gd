class_name AnchorVisualController
extends Node2D

const CHAIN_TEXTURE: Texture2D = preload(
	"res://visual/tiles/tile_chain.png"
)
const CLAMP_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_object_clamp.png"
)
const WINCH_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_object_winch_post.png"
)
const ANCHOR_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_object_anchor.png"
)

const CHAIN_LINK_SIZE: Vector2 = Vector2(46.0, 46.0)
const CHAIN_LINK_SPACING: float = 23.0
const CHAIN_BACKING_WIDTH: float = 7.0
const CHAIN_BRIGHTEN_AMOUNT: float = 0.18
const ALPHA_CROP_THRESHOLD: float = 0.08

@export_group("Anchor Assets")
@export var clamp_size: Vector2 = Vector2(76.0, 58.0)
@export var clamp_ground_offset: Vector2 = Vector2(0.0, 4.0)
@export var clamp_chain_connection_offset: Vector2 = Vector2(0.0, -34.0)
@export var anchor_size: Vector2 = Vector2(58.0, 72.0)
@export var stowed_chain_length: float = 28.0
@export var winch_size: Vector2 = Vector2(94.0, 88.0)
@export var winch_vertical_offset: float = -76.0
@export var winch_horizontal_offset: float = 0.0

var _store: AnchorRuntimeStore
var _geometry: AnchorGeometry
var _balance: AnchorBalance
var _is_operator_available: Callable
var _is_simulation_active: Callable
var _warning_elapsed: float = 0.0
var _chain_source_rect: Rect2
var _clamp_source_rect: Rect2
var _winch_source_rect: Rect2
var _anchor_source_rect: Rect2


func _ready() -> void:
	_chain_source_rect = _get_alpha_bounds(CHAIN_TEXTURE)
	_clamp_source_rect = _get_alpha_bounds(CLAMP_TEXTURE)
	_winch_source_rect = _get_alpha_bounds(WINCH_TEXTURE)
	_anchor_source_rect = _get_alpha_bounds(ANCHOR_TEXTURE)


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
	if (
		_is_simulation_active.is_valid()
		and bool(_is_simulation_active.call())
	):
		_warning_elapsed += maxf(0.0, delta)
	queue_redraw()


func _draw() -> void:
	if _store == null:
		return
	_draw_winch_posts()
	for anchor: AnchorRuntime in _store.get_all():
		_draw_anchor(anchor)


func _draw_winch_posts() -> void:
	var left_outer: Vector2 = _geometry.get_platform_attachment_world(0)
	var left_inner: Vector2 = _geometry.get_platform_attachment_world(1)
	var right_inner: Vector2 = _geometry.get_platform_attachment_world(2)
	var right_outer: Vector2 = _geometry.get_platform_attachment_world(3)
	var left_center := Vector2(
		(left_outer.x + left_inner.x) * 0.5 + winch_horizontal_offset,
		left_outer.y + winch_vertical_offset
	)
	var right_center := Vector2(
		(right_inner.x + right_outer.x) * 0.5 - winch_horizontal_offset,
		right_outer.y + winch_vertical_offset
	)
	_draw_winch(
		left_center,
		false,
		bool(_is_operator_available.call(AnchorRuntime.Side.LEFT))
	)
	_draw_winch(
		right_center,
		true,
		bool(_is_operator_available.call(AnchorRuntime.Side.RIGHT))
	)


func _draw_winch(center: Vector2, mirrored: bool, operator_available: bool) -> void:
	var tint := Color.WHITE
	if not operator_available:
		tint = Color(0.52, 0.55, 0.58, 1.0)
	var rect := Rect2(-winch_size * 0.5, winch_size)
	var scale := Vector2(-1.0, 1.0) if mirrored else Vector2.ONE
	draw_set_transform(center, 0.0, scale)
	draw_texture_rect_region(
		WINCH_TEXTURE,
		rect,
		_winch_source_rect,
		tint
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_anchor(anchor: AnchorRuntime) -> void:
	var platform_point: Vector2 = _geometry.get_platform_attachment_world(
		anchor.anchor_id
	)

	match anchor.state:
		AnchorRuntime.State.STOWED:
			_draw_stowed_anchor(anchor, platform_point)
			_draw_available_clamp(anchor)
		AnchorRuntime.State.QUEUED:
			_draw_stowed_anchor(anchor, platform_point)
			_draw_clamp(
				anchor.target_ground_point,
				_get_clamp_tint(anchor)
			)
		AnchorRuntime.State.INSTALLING:
			_draw_installing_anchor(anchor, platform_point)
		AnchorRuntime.State.ATTACHED, AnchorRuntime.State.OVERLOADED:
			_draw_attached_anchor(
				anchor,
				platform_point,
				_geometry.get_runtime_ground_point(anchor)
			)
		AnchorRuntime.State.RETURNING:
			_draw_returning_anchor(
				anchor,
				platform_point,
				_geometry.get_runtime_ground_point(anchor)
			)


func _draw_stowed_anchor(
	anchor: AnchorRuntime,
	platform_point: Vector2
) -> void:
	var anchor_top := platform_point + Vector2(0.0, stowed_chain_length)
	var tint := Color.WHITE
	if not bool(_is_operator_available.call(anchor.side)):
		tint = Color(0.68, 0.7, 0.72, 1.0)
	_draw_chain_links(platform_point, anchor_top, tint)
	_draw_anchor_asset(anchor_top, tint)


func _draw_available_clamp(anchor: AnchorRuntime) -> void:
	if _geometry.get_current_installation_orb_id() < 0:
		return
	_draw_clamp(
		_geometry.get_current_silhouette_ground_point(anchor.anchor_id),
		_get_clamp_tint(anchor)
	)


func _draw_installing_anchor(
	anchor: AnchorRuntime,
	platform_point: Vector2
) -> void:
	var ground_point: Vector2 = anchor.target_ground_point
	var visual_ground_point: Vector2 = _get_clamp_connection_point(ground_point)
	var progress_ratio: float = clampf(
		anchor.operation_progress / maxf(_balance.install_duration, 0.01),
		0.0,
		1.0
	)
	var anchor_top: Vector2 = platform_point.lerp(
		visual_ground_point,
		progress_ratio
	)
	var tint := Color(0.92, 0.82, 0.55, 1.0)
	_draw_clamp(ground_point, _get_clamp_tint(anchor))
	_draw_chain_links(platform_point, anchor_top, tint)
	_draw_anchor_asset(anchor_top, tint)


func _draw_attached_anchor(
	anchor: AnchorRuntime,
	platform_point: Vector2,
	ground_point: Vector2
) -> void:
	var durability_ratio: float = _get_durability_ratio(anchor)
	var rope_color: Color = Color(0.92, 0.75, 0.36)
	if durability_ratio <= _balance.rope_critical_ratio:
		var critical_pulse: float = 0.5 + 0.5 * sin(
			_warning_elapsed * _balance.rope_warning_pulse_speed
		)
		rope_color = Color(1.0, 0.08, 0.04).lerp(
			Color(1.0, 0.65, 0.12),
			critical_pulse
		)
	elif durability_ratio <= _balance.rope_damaged_ratio:
		rope_color = Color(1.0, 0.42, 0.08)

	if anchor.state == AnchorRuntime.State.OVERLOADED:
		var overload_pulse: float = 0.5 + 0.5 * sin(
			_warning_elapsed * _balance.rope_warning_pulse_speed * 1.4
		)
		rope_color = Color(1.0, 0.05, 0.03).lerp(
			Color(1.0, 0.35, 0.08),
			overload_pulse
		)

	var connection_point: Vector2 = _get_clamp_connection_point(ground_point)
	_draw_clamp(ground_point, Color.WHITE)
	_draw_chain_links(platform_point, connection_point, rope_color)
	# The anchor head itself is hidden once it has locked into the ground clamp.
	_draw_durability_meter(
		platform_point.lerp(connection_point, 0.5),
		durability_ratio,
		rope_color
	)


func _draw_returning_anchor(
	anchor: AnchorRuntime,
	platform_point: Vector2,
	ground_point: Vector2
) -> void:
	var return_ratio: float = clampf(
		anchor.operation_progress / maxf(_balance.return_duration, 0.01),
		0.0,
		1.0
	)
	var connection_point: Vector2 = _get_clamp_connection_point(ground_point)
	var returning_top: Vector2 = connection_point.lerp(
		platform_point + Vector2(0.0, stowed_chain_length),
		return_ratio
	)
	var return_color := Color(0.85, 0.76, 0.46)
	_draw_clamp(ground_point, Color.WHITE)
	_draw_chain_links(platform_point, returning_top, return_color)
	_draw_anchor_asset(returning_top, return_color.lightened(0.12))


func _draw_chain_links(
	start_point: Vector2,
	end_point: Vector2,
	tint: Color
) -> void:
	var segment: Vector2 = end_point - start_point
	var length: float = segment.length()
	if length <= 0.01:
		return

	var direction: Vector2 = segment / length
	var link_count: int = maxi(1, ceili(length / CHAIN_LINK_SPACING))
	var step: float = length / float(link_count)
	var rotation: float = direction.angle() - PI * 0.5
	var link_rect := Rect2(-CHAIN_LINK_SIZE * 0.5, CHAIN_LINK_SIZE)
	var visible_tint: Color = tint.lightened(CHAIN_BRIGHTEN_AMOUNT)
	visible_tint.a = 1.0
	var backing_color: Color = visible_tint
	backing_color.a = 0.4

	draw_line(
		start_point,
		end_point,
		backing_color,
		CHAIN_BACKING_WIDTH,
		true
	)

	for index: int in range(link_count):
		var link_position := (
			start_point
			+ direction * (step * (float(index) + 0.5))
		)
		draw_set_transform(link_position, rotation, Vector2.ONE)
		draw_texture_rect_region(
			CHAIN_TEXTURE,
			link_rect,
			_chain_source_rect,
			visible_tint
		)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_anchor_asset(anchor_top: Vector2, tint: Color) -> void:
	var rect := Rect2(
		Vector2(-anchor_size.x * 0.5, 0.0),
		anchor_size
	)
	draw_set_transform(anchor_top, 0.0, Vector2.ONE)
	draw_texture_rect_region(
		ANCHOR_TEXTURE,
		rect,
		_anchor_source_rect,
		tint
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_clamp(ground_point: Vector2, tint: Color) -> void:
	var bottom_center: Vector2 = ground_point + clamp_ground_offset
	var rect := Rect2(
		bottom_center + Vector2(-clamp_size.x * 0.5, -clamp_size.y),
		clamp_size
	)
	draw_texture_rect_region(
		CLAMP_TEXTURE,
		rect,
		_clamp_source_rect,
		tint
	)


func _get_clamp_tint(anchor: AnchorRuntime) -> Color:
	if not bool(_is_operator_available.call(anchor.side)):
		return Color(0.48, 0.5, 0.53, 0.78)
	if anchor.state == AnchorRuntime.State.QUEUED:
		return Color(1.0, 0.82, 0.35, 0.92)
	if anchor.state == AnchorRuntime.State.INSTALLING:
		return Color(0.5, 0.88, 1.0, 0.96)
	return Color(0.52, 1.0, 0.65, 0.9)


func _get_clamp_connection_point(ground_point: Vector2) -> Vector2:
	return ground_point + clamp_chain_connection_offset


func _draw_durability_meter(
	center: Vector2,
	ratio: float,
	fill_color: Color
) -> void:
	var bar_size := Vector2(44.0, 6.0)
	var bar_rect := Rect2(center - bar_size * 0.5, bar_size)
	draw_rect(bar_rect.grow(2.0), Color(0.08, 0.06, 0.05, 0.9), true)
	draw_rect(
		Rect2(bar_rect.position, Vector2(bar_size.x * ratio, bar_size.y)),
		fill_color,
		true
	)
	draw_rect(bar_rect, Color(1.0, 0.92, 0.72, 0.8), false, 1.0)
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


func _get_alpha_bounds(texture: Texture2D) -> Rect2:
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return Rect2(Vector2.ZERO, texture.get_size())

	var width: int = image.get_width()
	var height: int = image.get_height()
	var min_x: int = width
	var min_y: int = height
	var max_x: int = -1
	var max_y: int = -1

	for y: int in range(height):
		for x: int in range(width):
			if image.get_pixel(x, y).a <= ALPHA_CROP_THRESHOLD:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)

	if max_x < min_x or max_y < min_y:
		return Rect2(Vector2.ZERO, texture.get_size())

	return Rect2(
		Vector2(float(min_x), float(min_y)),
		Vector2(
			float(max_x - min_x + 1),
			float(max_y - min_y + 1)
		)
	)
