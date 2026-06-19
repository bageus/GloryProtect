class_name AnchorOperationQueue
extends RefCounted

signal installation_finished(side: int, anchor_id: int, attached: bool)

var _store: AnchorRuntimeStore
var _geometry: AnchorGeometry
var _balance: AnchorBalance
var _platform: PlatformController
var _active_install_ids := PackedInt32Array([-1, -1])
var _queues: Array = [[], []]
var _remove_all_pending: Array[bool] = [false, false]


func configure(
	store: AnchorRuntimeStore,
	geometry: AnchorGeometry,
	balance: AnchorBalance,
	platform: PlatformController
) -> void:
	_store = store
	_geometry = geometry
	_balance = balance
	_platform = platform


func request_install(anchor_id: int) -> void:
	var anchor := _store.get_anchor(anchor_id)
	var side := anchor.side
	if _active_install_ids[side] >= 0:
		_store.set_queued(anchor_id)
		_queues[side].append(anchor_id)
		return
	_start_install(anchor_id)


func tick(delta: float) -> void:
	_update_installations(delta)
	_update_returning_anchors(delta)


func request_remove_all(side: int) -> bool:
	cancel_queued(side)
	if has_active_install(side):
		_remove_all_pending[side] = true
		return false
	return true


func consume_remove_all_pending(side: int) -> bool:
	if not _remove_all_pending[side]:
		return false
	_remove_all_pending[side] = false
	return true


func has_active_install(side: int) -> bool:
	return _active_install_ids[side] >= 0


func start_next_if_allowed(side: int, allowed: bool) -> bool:
	if not allowed:
		cancel_queued(side)
		return false

	while not _queues[side].is_empty():
		var next_id: int = _queues[side].pop_front()
		var next_anchor := _store.get_anchor(next_id)
		if next_anchor.state != AnchorRuntime.State.QUEUED:
			continue
		_start_install(next_id)
		return true
	return false


func cancel_queued(side: int) -> void:
	for queued_id in _queues[side]:
		var anchor := _store.get_anchor(int(queued_id))
		if anchor.state == AnchorRuntime.State.QUEUED:
			_store.set_stowed(anchor.anchor_id)
	_queues[side].clear()


func _start_install(anchor_id: int) -> void:
	var anchor := _store.get_anchor(anchor_id)
	_active_install_ids[anchor.side] = anchor_id
	_store.begin_install(anchor_id)


func _update_installations(delta: float) -> void:
	for side in [AnchorRuntime.Side.LEFT, AnchorRuntime.Side.RIGHT]:
		var anchor_id := _active_install_ids[side]
		if anchor_id < 0:
			continue

		var progress := _store.advance_operation(anchor_id, delta)
		if progress < _balance.install_duration:
			continue

		var attached := _geometry.is_within_rope_length(anchor_id)
		if attached:
			_store.attach(anchor_id, _platform.position.x)
		else:
			_store.begin_return(anchor_id)

		_active_install_ids[side] = -1
		installation_finished.emit(side, anchor_id, attached)


func _update_returning_anchors(delta: float) -> void:
	for anchor in _store.get_all():
		if anchor.state != AnchorRuntime.State.RETURNING:
			continue
		var progress := _store.advance_operation(anchor.anchor_id, delta)
		if progress >= _balance.return_duration:
			_store.set_stowed(anchor.anchor_id)
