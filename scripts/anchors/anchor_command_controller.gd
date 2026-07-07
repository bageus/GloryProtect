class_name AnchorCommandController
extends RefCounted

signal anchor_detaching(anchor_id: int)
signal anchor_removed(anchor_id: int)
signal command_rejected(anchor_id: int, reason: StringName)

var _store: AnchorRuntimeStore
var _geometry: AnchorGeometry
var _operations: AnchorOperationQueue
var _is_operator_available: Callable
var _instant_remove_all_enabled: bool = false
var _second_winch_pair_enabled: bool = false


func configure(
	store: AnchorRuntimeStore,
	geometry: AnchorGeometry,
	operations: AnchorOperationQueue,
	is_operator_available: Callable
) -> void:
	_store = store
	_geometry = geometry
	_operations = operations
	_is_operator_available = is_operator_available


func set_instant_remove_all_enabled(enabled: bool) -> void:
	_instant_remove_all_enabled = enabled


func is_instant_remove_all_enabled() -> bool:
	return _instant_remove_all_enabled


func set_second_winch_pair_enabled(enabled: bool) -> void:
	_second_winch_pair_enabled = enabled


func is_second_winch_pair_enabled() -> bool:
	return _second_winch_pair_enabled


func toggle(anchor_id: int) -> void:
	if not _store.is_valid(anchor_id):
		return

	var anchor := _store.get_anchor(anchor_id)
	match anchor.state:
		AnchorRuntime.State.STOWED:
			_request_install(anchor)
		AnchorRuntime.State.ATTACHED, AnchorRuntime.State.OVERLOADED:
			_request_remove(anchor)
		_:
			command_rejected.emit(anchor_id, &"anchor_busy")


func request_remove_all() -> void:
	for side in [AnchorRuntime.Side.LEFT, AnchorRuntime.Side.RIGHT]:
		if not _instant_remove_all_enabled and not _operator_available(side):
			continue
		var can_remove_now: bool = _operations.request_remove_all(side)
		if _instant_remove_all_enabled:
			# Existing anchors detach immediately. An already-started installation
			# remains atomic and is detached by AnchorSystem when it completes.
			remove_all_on_side(side)
		elif can_remove_now:
			remove_all_on_side(side)


func remove_all_on_side(side: int) -> void:
	var holding: Array[AnchorRuntime] = _store.get_holding_on_side(side)
	for anchor: AnchorRuntime in holding:
		anchor_detaching.emit(anchor.anchor_id)
		_store.set_stowed(anchor.anchor_id)
		anchor_removed.emit(anchor.anchor_id)


func operator_availability_changed(side: int, is_available: bool) -> void:
	if not is_available:
		_operations.cancel_queued(side)


func _request_install(anchor: AnchorRuntime) -> void:
	if not _can_install_anchor_on_side(anchor):
		command_rejected.emit(anchor.anchor_id, &"second_winch_locked")
		return
	var orb_id := _geometry.get_current_installation_orb_id()
	if orb_id < 0:
		command_rejected.emit(anchor.anchor_id, &"outside_installation_zone")
		return
	if not _operator_available(anchor.side):
		command_rejected.emit(anchor.anchor_id, &"operator_missing")
		return

	var ground_point := _geometry.get_ground_point_for_orb(
		orb_id,
		anchor.anchor_id
	)
	_operations.request_install(anchor.anchor_id, orb_id, ground_point)


func _request_remove(anchor: AnchorRuntime) -> void:
	if not _operator_available(anchor.side):
		command_rejected.emit(anchor.anchor_id, &"operator_missing")
		return

	# Timed removal will be added with physical operator animations.
	anchor_detaching.emit(anchor.anchor_id)
	_store.set_stowed(anchor.anchor_id)
	anchor_removed.emit(anchor.anchor_id)


func _can_install_anchor_on_side(anchor: AnchorRuntime) -> bool:
	if _second_winch_pair_enabled:
		return true
	for other: AnchorRuntime in _store.get_all():
		if other.anchor_id == anchor.anchor_id or other.side != anchor.side:
			continue
		if other.state != AnchorRuntime.State.STOWED:
			return false
	return true


func _operator_available(side: int) -> bool:
	return bool(_is_operator_available.call(side))
