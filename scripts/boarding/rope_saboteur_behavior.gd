class_name RopeSaboteurBehavior
extends EnemyBehaviorComponent

enum State {
	WAITING_WITHOUT_PATH,
	RUNNING_TO_ROPE,
	ARMING,
	DEAD,
}

var state: int = State.WAITING_WITHOUT_PATH
var selected_anchor_id: int = -1
var _arming_elapsed: float = 0.0
var _profile: RopeSaboteurArchetype


func _on_configured() -> void:
	assert(context != null, "RopeSaboteurBehavior requires context")
	assert(enemy.archetype is RopeSaboteurArchetype)
	_profile = enemy.archetype as RopeSaboteurArchetype
	target_domain = TargetDomain.OBJECT
	counts_as_ground = true
	counts_as_climbing = false
	counts_as_boarded = false
	turret_targetable = true
	_set_state(State.WAITING_WITHOUT_PATH)
	_set_ground_height()


func _on_stopped() -> void:
	selected_anchor_id = -1
	_arming_elapsed = 0.0
	state = State.DEAD
	publish_visual_state(&"dead")


func _tick_behavior(delta: float) -> void:
	match state:
		State.WAITING_WITHOUT_PATH:
			_update_waiting(delta)
		State.RUNNING_TO_ROPE:
			_update_running(delta)
		State.ARMING:
			_update_arming(delta)


func is_targetable_by_turret() -> bool:
	return active and state == State.ARMING


func get_selected_anchor_id() -> int:
	return selected_anchor_id


func get_arming_progress() -> float:
	if _profile == null or _profile.arming_duration <= 0.0:
		return 0.0
	return clampf(_arming_elapsed / _profile.arming_duration, 0.0, 1.0)


func is_arming() -> bool:
	return active and state == State.ARMING


func _update_waiting(delta: float) -> void:
	var path: AnchorPathSnapshot = _choose_target_path()
	if path != null:
		selected_anchor_id = path.anchor_id
		_set_state(State.RUNNING_TO_ROPE)
		return

	var desired_x: float = move_toward(
		enemy.global_position.x,
		context.platform.global_position.x,
		_profile.ground_move_speed * delta
	)
	enemy.global_position.x = context.movement_resolver.resolve_ground_x(
		enemy,
		enemy.global_position.x,
		desired_x
	)
	_set_ground_height()


func _update_running(delta: float) -> void:
	var path: AnchorPathSnapshot = _get_selected_path_or_reset()
	if path == null:
		return

	var desired_x: float = move_toward(
		enemy.global_position.x,
		path.ground_point.x,
		_profile.ground_move_speed * delta
	)
	enemy.global_position.x = context.movement_resolver.resolve_ground_x(
		enemy,
		enemy.global_position.x,
		desired_x
	)
	_set_ground_height()

	if (
		absf(enemy.global_position.x - path.ground_point.x)
		> context.boarding_balance.ground_arrival_epsilon
	):
		return
	enemy.global_position = path.ground_point
	_arming_elapsed = 0.0
	_set_state(State.ARMING)


func _update_arming(delta: float) -> void:
	var path: AnchorPathSnapshot = _get_selected_path_or_reset()
	if path == null:
		return
	enemy.global_position = path.ground_point
	_arming_elapsed = minf(
		_profile.arming_duration,
		_arming_elapsed + delta
	)
	if _arming_elapsed < _profile.arming_duration:
		return

	if context.anchors.apply_rope_damage(
		selected_anchor_id,
		_profile.rope_damage,
		&"rope_saboteur"
	):
		enemy.kill(&"rope_sabotage")
		return
	_reset_target()


func _choose_target_path() -> AnchorPathSnapshot:
	var excluded_anchor_ids: Array[int] = []
	for snapshot: AnchorRopeSnapshot in context.anchors.get_all_rope_snapshots():
		if snapshot.is_destroyed:
			excluded_anchor_ids.append(snapshot.anchor_id)
	return context.paths.choose_nearest_path(
		enemy.global_position.x,
		excluded_anchor_ids
	)


func _get_selected_path_or_reset() -> AnchorPathSnapshot:
	if (
		not context.paths.is_path_available(selected_anchor_id)
		or not _is_selected_rope_damageable()
	):
		_reset_target()
		return null
	var path: AnchorPathSnapshot = context.paths.get_anchor_path(selected_anchor_id)
	if path == null:
		_reset_target()
	return path


func _is_selected_rope_damageable() -> bool:
	var snapshot: AnchorRopeSnapshot = context.anchors.get_rope_snapshot(
		selected_anchor_id
	)
	return snapshot != null and not snapshot.is_destroyed


func _reset_target() -> void:
	selected_anchor_id = -1
	_arming_elapsed = 0.0
	_set_state(State.WAITING_WITHOUT_PATH)


func _set_state(new_state: int) -> void:
	state = new_state
	match state:
		State.WAITING_WITHOUT_PATH:
			publish_visual_state(&"waiting")
		State.RUNNING_TO_ROPE:
			publish_visual_state(&"running_to_rope")
		State.ARMING:
			publish_visual_state(&"arming")
		State.DEAD:
			publish_visual_state(&"dead")


func _set_ground_height() -> void:
	enemy.global_position.y = (
		context.orbs.catalog.ground_y
		- context.boarding_balance.ground_vertical_offset
	)
