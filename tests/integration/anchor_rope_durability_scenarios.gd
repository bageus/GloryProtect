extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root.tscn")

var _destroyed_ids: Array[int] = []


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game: Node = GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame

	var game_flow: GameFlowController = game.get_node("GameFlowController")
	var platform: PlatformController = game.get_node("World/Platform")
	var wind: WindSystem = game.get_node("WindSystem")
	var anchors: AnchorSystem = game.get_node("World/AnchorSystem")

	game_flow.state = GameFlowController.RunState.RUNNING
	wind.balance.level_forces = PackedFloat32Array([0.0, 0.0, 0.0])
	wind.balance.fluctuation_force = 0.0
	wind.set_debug_state(1, 1)
	platform.position.x = 0.0
	platform.horizontal_velocity = 0.0

	assert(anchors.get_all_rope_snapshots().size() == 4)
	assert(not anchors.apply_rope_damage(2, 10.0, &"stowed"))

	anchors.toggle_anchor(2)
	await _wait_physics_frames(120)
	assert(anchors.is_path_available(2))

	var maximum: float = anchors.balance.rope_max_durability
	var attached_snapshot: AnchorRopeSnapshot = anchors.get_rope_snapshot(2)
	assert(is_equal_approx(attached_snapshot.current_durability, maximum))
	assert(anchors.apply_rope_damage(2, maximum * 0.25, &"integration"))
	assert(is_equal_approx(
		anchors.get_rope_snapshot(2).durability_ratio,
		0.75
	))
	assert(is_equal_approx(
		anchors.get_rope_snapshot(0).current_durability,
		maximum
	))

	anchors.rope_destroyed.connect(_on_rope_destroyed)
	assert(anchors.apply_rope_damage(2, maximum, &"integration_destroy"))
	assert(_destroyed_ids == [2])
	assert(anchors.get_rope_snapshot(2).is_destroyed)
	assert(not anchors.is_path_available(2))
	assert(anchors.get_anchor_state(2) == AnchorRuntime.State.RETURNING)

	assert(await _wait_until(
		func() -> bool:
			return anchors.get_anchor_state(2) == AnchorRuntime.State.STOWED,
		180
	))
	anchors.toggle_anchor(2)
	assert(await _wait_until(
		func() -> bool: return anchors.is_path_available(2),
		240
	))
	assert(is_equal_approx(
		anchors.get_rope_snapshot(2).current_durability,
		maximum
	))

	print("Anchor rope durability integration scenarios passed")
	quit()


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame: int in range(maximum_frames):
		if predicate.call():
			return true
		await physics_frame
	return predicate.call()


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await physics_frame


func _on_rope_destroyed(anchor_id: int, _source: StringName) -> void:
	_destroyed_ids.append(anchor_id)
