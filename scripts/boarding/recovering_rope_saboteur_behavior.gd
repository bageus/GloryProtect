class_name RecoveringRopeSaboteurBehavior
extends RopeSaboteurBehavior


func _on_configured() -> void:
	super._on_configured()
	_connect_path_signals()
	_resume_waiting_target()


func _on_stopped() -> void:
	_disconnect_path_signals()
	super._on_stopped()


func get_ground_target_x() -> float:
	if selected_anchor_id >= 0:
		var selected: AnchorPathSnapshot = context.paths.get_anchor_path(
			selected_anchor_id
		)
		if selected != null:
			return selected.ground_point.x
	var path: AnchorPathSnapshot = _choose_target_path()
	if path != null:
		return path.ground_point.x
	if context != null and context.platform != null:
		return context.platform.global_position.x
	return enemy.global_position.x if enemy != null else 0.0


func _choose_target_path() -> AnchorPathSnapshot:
	var excluded_anchor_ids: Array[int] = []
	for snapshot: AnchorRopeSnapshot in context.anchors.get_all_rope_snapshots():
		if snapshot.is_destroyed:
			excluded_anchor_ids.append(snapshot.anchor_id)
	return context.paths.choose_nearest_path_deterministic(
		enemy.global_position.x,
		excluded_anchor_ids
	)


func _connect_path_signals() -> void:
	if context == null or context.paths == null:
		return
	if not context.paths.path_opened.is_connected(_on_path_opened):
		context.paths.path_opened.connect(_on_path_opened)
	if not context.paths.path_closed.is_connected(_on_path_closed):
		context.paths.path_closed.connect(_on_path_closed)


func _disconnect_path_signals() -> void:
	if context == null or context.paths == null:
		return
	if context.paths.path_opened.is_connected(_on_path_opened):
		context.paths.path_opened.disconnect(_on_path_opened)
	if context.paths.path_closed.is_connected(_on_path_closed):
		context.paths.path_closed.disconnect(_on_path_closed)


func _on_path_opened(_anchor_id: int) -> void:
	if not active or state != State.WAITING_WITHOUT_PATH:
		return
	_resume_waiting_target()


func _on_path_closed(anchor_id: int) -> void:
	if not active or state == State.DEAD:
		return
	if selected_anchor_id != anchor_id:
		return
	_reset_target()
	_resume_waiting_target()


func _resume_waiting_target() -> void:
	if not active or state != State.WAITING_WITHOUT_PATH:
		return
	var path: AnchorPathSnapshot = _choose_target_path()
	if path == null:
		return
	selected_anchor_id = path.anchor_id
	_set_state(State.RUNNING_TO_ROPE)
