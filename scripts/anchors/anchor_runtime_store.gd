class_name AnchorRuntimeStore
extends RefCounted

signal anchor_state_changed(anchor_id: int, state: int)

var _anchors: Array[AnchorRuntime] = []


func initialize() -> void:
	_anchors.clear()
	for anchor_id in range(4):
		var side := AnchorRuntime.Side.LEFT if anchor_id < 2 else AnchorRuntime.Side.RIGHT
		_anchors.append(AnchorRuntime.new(anchor_id, side))


func is_valid(anchor_id: int) -> bool:
	return anchor_id >= 0 and anchor_id < _anchors.size()


func get_anchor(anchor_id: int) -> AnchorRuntime:
	assert(is_valid(anchor_id), "Invalid anchor id: %d" % anchor_id)
	return _anchors[anchor_id]


func get_all() -> Array[AnchorRuntime]:
	return _anchors


func set_install_target(
	anchor_id: int,
	orb_id: int,
	ground_point: Vector2
) -> void:
	var anchor := get_anchor(anchor_id)
	anchor.target_orb_id = orb_id
	anchor.target_ground_point = ground_point


func set_queued(anchor_id: int) -> void:
	_set_state(anchor_id, AnchorRuntime.State.QUEUED)


func begin_install(anchor_id: int) -> void:
	var anchor := get_anchor(anchor_id)
	anchor.operation_progress = 0.0
	_set_state(anchor_id, AnchorRuntime.State.INSTALLING)


func advance_operation(anchor_id: int, delta: float) -> float:
	var anchor := get_anchor(anchor_id)
	anchor.operation_progress += delta
	return anchor.operation_progress


func attach(anchor_id: int, platform_x: float) -> void:
	var anchor := get_anchor(anchor_id)
	anchor.operation_progress = 0.0
	anchor.overload_progress = 0.0
	anchor.attached_platform_x = platform_x
	anchor.attached_orb_id = anchor.target_orb_id
	anchor.attached_ground_point = anchor.target_ground_point
	_set_state(anchor_id, AnchorRuntime.State.ATTACHED)


func begin_overload(anchor_id: int) -> void:
	var anchor := get_anchor(anchor_id)
	anchor.overload_progress = 0.0
	_set_state(anchor_id, AnchorRuntime.State.OVERLOADED)


func advance_overload(anchor_id: int, delta: float) -> float:
	var anchor := get_anchor(anchor_id)
	anchor.overload_progress += delta
	return anchor.overload_progress


func cancel_overload(anchor_id: int) -> void:
	var anchor := get_anchor(anchor_id)
	if anchor.state != AnchorRuntime.State.OVERLOADED:
		return
	anchor.overload_progress = 0.0
	_set_state(anchor_id, AnchorRuntime.State.ATTACHED)


func begin_return(anchor_id: int) -> void:
	var anchor := get_anchor(anchor_id)
	anchor.operation_progress = 0.0
	anchor.overload_progress = 0.0
	if not anchor.has_attachment() and anchor.has_target():
		anchor.attached_orb_id = anchor.target_orb_id
		anchor.attached_ground_point = anchor.target_ground_point
	_set_state(anchor_id, AnchorRuntime.State.RETURNING)


func set_stowed(anchor_id: int) -> void:
	var anchor := get_anchor(anchor_id)
	anchor.operation_progress = 0.0
	anchor.overload_progress = 0.0
	anchor.clear_ground_binding()
	_set_state(anchor_id, AnchorRuntime.State.STOWED)


func get_holding_on_side(side: int) -> Array[AnchorRuntime]:
	var result: Array[AnchorRuntime] = []
	for anchor in _anchors:
		if anchor.side == side and anchor.is_holding():
			result.append(anchor)
	return result


func count_holding_on_side(side: int) -> int:
	return get_holding_on_side(side).size()


func get_state_summary() -> String:
	var parts := PackedStringArray()
	for anchor in _anchors:
		var orb_suffix := ""
		if anchor.has_attachment():
			orb_suffix = "@O%d" % (anchor.attached_orb_id + 1)
		elif anchor.has_target():
			orb_suffix = "@O%d" % (anchor.target_orb_id + 1)
		parts.append(
			"%d:%s%s" % [
				anchor.anchor_id + 1,
				AnchorRuntime.State.keys()[anchor.state],
				orb_suffix,
			]
		)
	return "  ".join(parts)


func _set_state(anchor_id: int, new_state: int) -> void:
	var anchor := get_anchor(anchor_id)
	if anchor.state == new_state:
		return
	anchor.state = new_state
	anchor_state_changed.emit(anchor_id, new_state)
