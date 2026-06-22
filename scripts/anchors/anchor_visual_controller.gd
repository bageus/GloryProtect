class_name AnchorVisualController
extends Node2D

const CHAIN_TEXTURE: Texture2D = preload(
	"res://visual/tiles/tile_chain.png"
)
const CHAIN_LINK_SIZE: Vector2 = Vector2(46.0, 46.0)
const CHAIN_LINK_SPACING: float = 23.0
const CHAIN_BACKING_WIDTH: float = 7.0
const CHAIN_BRIGHTEN_AMOUNT: float = 0.18
const CHAIN_ALPHA_CROP_THRESHOLD: float = 0.08

var _store: AnchorRuntimeStore
var _geometry: AnchorGeometry
var _balance: AnchorBalance
var _is_operator_available: Callable
var _is_simulation_active: Callable
var _warning_elapsed: float = 0.0
var _chain_source_rect: Rect2


func _ready() -> void:
	_chain_source_rect = _get_alpha_bounds(
		CHAIN_TEXTURE,
		CHAIN_ALPHA_CROP_THRESHOLD
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
	if (
		_is_simulation_active.is_valid()
		and bool(_is_simulation_active.call())
	):
		_warning_elapsed += maxf(0.0, delta)
	queue_redraw()


func _draw() -> void:
	if _store == null:
		return
	for anchor in _store.get_all():
		_draw_anchor(anchor)


func _draw_anchor(anchor: AnchorRuntime) -> void:
	var platform_point := _geometry.get_platform_attachment_world(anchor.anchor_id)

	if anchor.is_holding():
		_draw_attached_anchor(
			anchor,
			platform_point,
			_geometry.get_runtime_ground_point(anchor)
		)
		return

	if anchor.state == AnchorRuntime.State.RETURNING:
		_draw_returning_anchor(
			anchor,
			platform_point,
			_geometry.get_runtime_ground_point(anchor)
		)
		return

	if (
		anchor.state == AnchorRuntime.State.QUEUED
		or anchor.state == AnchorRuntime.State.INSTALLING
	):
		_draw_silhouette(anchor, anchor.target_ground_point)
		return

	if _geometry.get_current_installation_orb_id() < 0:
		return
	_draw_silhouette(
		anchor,
		_geometry.get_current_silhouette_ground_point(anchor.anchor_id)
	)


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

	_draw_chain_links(platform_point, ground_point, rope_color)
	draw_circle(ground_point, 10.0, rope_color)
	_draw_durability_meter(
		platform_point.lerp(ground_point, 0.5),
		durability_ratio,
		rope_color
	)


func _draw_chain_links(
	start_point: Vector2,
	end_point: Vector2,
	tint: Color
) -> void:
	var segment := end_point - start_point
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

	# A bright backing prevents the texture from disappearing against dark ground.
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


func _draw_returning_anchor(
	anchor: AnchorRuntime,
	platform_point: Vector2,
	ground_point: Vector2
) -> void:
	var return_ratio := clampf(
		anchor.operation_progress / _balance.return_duration,
		0.0,
		1.0
	)
	var returning_point := ground_point.lerp(platform_point, return_ratio)
	var return_color := Color(0.85, 0.76, 0.46)
	_draw_chain_links(platform_point, returning_point, return_color)
	draw_circle(returning_point, 9.0, return_color)


func _draw_silhouette(anchor: AnchorRuntime, ground_point: Vector2) -> void:
	var operator_available: bool = _is_operator_available.call(anchor.side)
	var silhouette_color := Color(0.28, 0.95, 0.48, 0.75)

	if not operator_available:
		silhouette_color = Color(0.45, 0.48, 0.52, 0.65)
	elif anchor.state == AnchorRuntime.State.QUEUED:
		silhouette_color = Color(1.0, 0.78, 0.2, 0.8)
	elif anchor.state == AnchorRuntime.State.INSTALLING:
		silhouette_color = Color(0.35, 0.78, 1.0, 0.85)

	draw_circle(ground_point, 14.0, silhouette_color)
	draw_line(
		ground_point + Vector2(-9.0, 15.0),
		ground_point + Vector2(9.0, 15.0),
		silhouette_color,
		4.0
	)


func _get_durability_ratio(anchor: AnchorRuntime) -> float:
	if _balance.rope_max_durability <= 0.0:
		return 0.0
	return clampf(
		anchor.rope_durability / _balance.rope_max_durability,
		0.0,
		1.0
	)


func _get_alpha_bounds(texture: Texture2D, threshold: float) -> Rect2:
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
			if image.get_pixel(x, y).a <= threshold:
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
