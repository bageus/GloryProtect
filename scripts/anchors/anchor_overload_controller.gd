class_name AnchorOverloadController
extends RefCounted

signal overload_started(anchor_id: int)
signal anchor_broken(anchor_id: int)

var _store: AnchorRuntimeStore
var _constraints: AnchorConstraintProvider
var _balance: AnchorBalance
var _wind: WindSystem
var _duration_bonus_seconds: float = 0.0
var _wind_strength_threshold: int = 2


func configure(
	store: AnchorRuntimeStore,
	constraints: AnchorConstraintProvider,
	balance: AnchorBalance,
	wind: WindSystem
) -> void:
	_store = store
	_constraints = constraints
	_balance = balance
	_wind = wind


func set_duration_bonus(seconds: float) -> void:
	_duration_bonus_seconds = maxf(0.0, seconds)


func set_wind_strength_threshold(strength_level: int) -> void:
	_wind_strength_threshold = maxi(1, strength_level)


func get_wind_strength_threshold() -> int:
	return _wind_strength_threshold


func get_effective_duration() -> float:
	return _balance.overload_duration + _duration_bonus_seconds


func tick(delta: float) -> void:
	for side in [AnchorRuntime.Side.LEFT, AnchorRuntime.Side.RIGHT]:
		_update_side(side, delta)


func _update_side(side: int, delta: float) -> void:
	var holding := _store.get_holding_on_side(side)
	if holding.size() >= 2:
		for anchor in holding:
			_store.cancel_overload(anchor.anchor_id)
		return

	if holding.is_empty():
		return

	var anchor: AnchorRuntime = holding[0]
	if not _should_overload(anchor):
		_store.cancel_overload(anchor.anchor_id)
		return

	if anchor.state == AnchorRuntime.State.ATTACHED:
		_store.begin_overload(anchor.anchor_id)
		overload_started.emit(anchor.anchor_id)

	var progress := _store.advance_overload(anchor.anchor_id, delta)
	if progress < get_effective_duration():
		return

	_store.begin_return(anchor.anchor_id)
	anchor_broken.emit(anchor.anchor_id)


func _should_overload(anchor: AnchorRuntime) -> bool:
	if _wind.strength_level < _wind_strength_threshold:
		return false

	# Tension is geometry-based. A right anchor can be loaded by wind to the
	# left immediately, or by wind to the right after the rope reaches its
	# finite length. The same rule applies symmetrically to left anchors.
	return _constraints.is_anchor_tensioned_in_wind(anchor.anchor_id)
