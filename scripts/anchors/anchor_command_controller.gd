class_name AnchorCommandController
extends RefCounted

signal anchor_removed(anchor_id: int)
signal command_rejected(anchor_id: int, reason: StringName)

var _store: AnchorRuntimeStore
var _geometry: AnchorGeometry
var _operations: AnchorOperationQueue
var _is_operator_available: Callable


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
		if _operations.request_remove_all(side):
			remove_all_on_side(side)


func remove_all_on_side(side: int) -> void:
	for anchor in _store.get_holding_on_side(side):
		_store.set_stowed(anchor.anchor_id)
		anchor_removed.emit(anchor.anchor_id)


func operator_availability_changed(side: int, is_available: bool) -> void:
	if not is_available:
		_operations.cancel_queued(side)


func _request_install(anchor: AnchorRuntime) -> void:
	if not _geometry.is_in_installation_zone():
		command_rejected.emit(anchor.anchor_id, &"outside_installation_zone")
		return
	if not _operator_available(anchor.side):
		command_rejected.emit(anchor.anchor_id, &"operator_missing")
		return
	_operations.request_install(anchor.anchor_id)


func _request_remove(anchor: AnchorRuntime) -> void:
	if not _operator_available(anchor.side):
		command_rejected.emit(anchor.anchor_id, &"operator_missing")
		return

	# Timed removal will be added with physical operator animations.
	_store.set_stowed(anchor.anchor_id)
	anchor_removed.emit(anchor.anchor_id)


func _operator_available(side: int) -> bool:
	return bool(_is_operator_available.call(side))
