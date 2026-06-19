class_name AnchorVisualController
extends Node2D

var _store: AnchorRuntimeStore
var _geometry: AnchorGeometry
var _balance: AnchorBalance
var _is_zone_active: Callable
var _is_operator_available: Callable


func configure(
	store: AnchorRuntimeStore,
	geometry: AnchorGeometry,
	balance: AnchorBalance,
	is_zone_active: Callable,
	is_operator_available: Callable
) -> void:
	_store = store
	_geometry = geometry
	_balance = balance
	_is_zone_active = is_zone_active
	_is_operator_available = is_operator_available


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _store == null:
		return

	var zone_active: bool = _is_zone_active.call()
	for anchor in _store.get_all():
		_draw_anchor(anchor, zone_active)


func _draw_anchor(anchor: AnchorRuntime, zone_active: bool) -> void:
	var ground_point := _geometry.get_ground_point(anchor.anchor_id)
	var platform_point := _geometry.get_platform_attachment_world(anchor.anchor_id)

	if anchor.is_holding():
		_draw_attached_anchor(anchor, platform_point, ground_point)
		return

	if anchor.state == AnchorRuntime.State.RETURNING:
		_draw_returning_anchor(anchor, platform_point, ground_point)
		return

	if not zone_active:
		return

	_draw_silhouette(anchor, ground_point)


func _draw_attached_anchor(
	anchor: AnchorRuntime,
	platform_point: Vector2,
	ground_point: Vector2
) -> void:
	var rope_color := Color(0.92, 0.75, 0.36)
	if anchor.state == AnchorRuntime.State.OVERLOADED:
		var flash := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.015)
		rope_color = Color(1.0, 0.12 + flash * 0.25, 0.08)

	draw_line(platform_point, ground_point, rope_color, 4.0)
	draw_circle(ground_point, 10.0, rope_color)


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
	draw_circle(returning_point, 9.0, Color(0.85, 0.76, 0.46))


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
