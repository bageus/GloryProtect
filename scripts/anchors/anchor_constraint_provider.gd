class_name AnchorConstraintProvider
extends RefCounted

var _store: AnchorRuntimeStore
var _geometry: AnchorGeometry
var _balance: AnchorBalance
var _platform: PlatformController
var _wind: WindSystem
var _fully_fixed: bool = false
var _fixed_platform_x: float = 0.0


func configure(
	store: AnchorRuntimeStore,
	geometry: AnchorGeometry,
	balance: AnchorBalance,
	platform: PlatformController,
	wind: WindSystem
) -> void:
	_store = store
	_geometry = geometry
	_balance = balance
	_platform = platform
	_wind = wind


func update_full_fix_state() -> void:
	var now_fully_fixed := (
		_store.count_holding_on_side(AnchorRuntime.Side.LEFT) > 0
		and _store.count_holding_on_side(AnchorRuntime.Side.RIGHT) > 0
	)
	if now_fully_fixed and not _fully_fixed:
		_fixed_platform_x = _platform.position.x
	_fully_fixed = now_fully_fixed


func is_fully_fixed() -> bool:
	return _fully_fixed


func get_fixed_platform_x() -> float:
	return _fixed_platform_x


func get_minimum_platform_x() -> float:
	var minimum_x := -INF
	for anchor in _store.get_all():
		if not anchor.is_holding():
			continue
		minimum_x = maxf(minimum_x, _get_anchor_min_x(anchor))
	return minimum_x


func get_maximum_platform_x() -> float:
	var maximum_x := INF
	for anchor in _store.get_all():
		if not anchor.is_holding():
			continue
		maximum_x = minf(maximum_x, _get_anchor_max_x(anchor))
	return maximum_x


func is_anchor_tensioned_in_wind(anchor_id: int) -> bool:
	var anchor := _store.get_anchor(anchor_id)
	var base_min := _geometry.get_directional_min_x(anchor)
	var base_max := _geometry.get_directional_max_x(anchor)
	if _wind.direction > 0:
		return _platform.position.x >= base_max - _balance.tension_epsilon
	return _platform.position.x <= base_min + _balance.tension_epsilon


func _get_anchor_min_x(anchor: AnchorRuntime) -> float:
	var minimum_x := _geometry.get_directional_min_x(anchor)
	if anchor.state == AnchorRuntime.State.OVERLOADED and _wind.direction < 0:
		minimum_x -= _get_overload_extension(anchor)
	return minimum_x


func _get_anchor_max_x(anchor: AnchorRuntime) -> float:
	var maximum_x := _geometry.get_directional_max_x(anchor)
	if anchor.state == AnchorRuntime.State.OVERLOADED and _wind.direction > 0:
		maximum_x += _get_overload_extension(anchor)
	return maximum_x


func _get_overload_extension(anchor: AnchorRuntime) -> float:
	var ratio := clampf(
		anchor.overload_progress / _balance.overload_duration,
		0.0,
		1.0
	)
	return _balance.overload_stretch * ratio
