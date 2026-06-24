extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root.tscn")
const TIMER_FRAME_TOLERANCE: float = 0.05


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var game_flow: GameFlowController = game.get_node("GameFlowController")
	var difficulty: RunDifficulty = game.get_node("RunDifficulty")
	var spawn: BoardingSpawnDirector = game.get_node(
		"World/BoardingSpawnDirector"
	)

	assert(game_flow.state == GameFlowController.RunState.START_DELAY)
	assert(is_equal_approx(difficulty.get_elapsed_seconds(), 0.0))
	var start_delay_spawn_remaining: float = spawn.get_spawn_remaining()
	await _wait_physics_frames(5)
	assert(is_equal_approx(difficulty.get_elapsed_seconds(), 0.0))
	assert(is_equal_approx(
		spawn.get_spawn_remaining(),
		start_delay_spawn_remaining
	))
	assert(spawn.get_current_ground_limit() == spawn.balance.max_ground_enemies)
	assert(is_equal_approx(
		spawn.get_current_spawn_interval(),
		spawn.balance.spawn_interval
	))

	game_flow.state = GameFlowController.RunState.RUNNING
	await _wait_process_frames(5)
	assert(difficulty.get_elapsed_seconds() > 0.0)

	difficulty.set_debug_elapsed_seconds(300.0)
	var midpoint: float = difficulty.get_normalized()
	assert(is_equal_approx(midpoint, 0.5))
	assert(spawn.get_current_ground_limit() == roundi(lerpf(
		float(spawn.balance.max_ground_enemies),
		float(spawn.balance.maximum_ground_enemies),
		midpoint
	)))
	assert(is_equal_approx(
		spawn.get_current_spawn_interval(),
		lerpf(
			spawn.balance.spawn_interval,
			spawn.balance.minimum_spawn_interval,
			midpoint
		)
	))
	await _wait_physics_frames(2)
	assert(
		spawn.get_spawn_remaining()
		<= spawn.get_current_spawn_interval() + TIMER_FRAME_TOLERANCE
	)

	game_flow.state = GameFlowController.RunState.CARD_SELECTION
	var paused_elapsed: float = difficulty.get_elapsed_seconds()
	var paused_spawn_remaining: float = spawn.get_spawn_remaining()
	await _wait_process_frames(5)
	await _wait_physics_frames(5)
	assert(is_equal_approx(difficulty.get_elapsed_seconds(), paused_elapsed))
	assert(is_equal_approx(
		spawn.get_spawn_remaining(),
		paused_spawn_remaining
	))

	difficulty.set_debug_elapsed_seconds(600.0)
	assert(is_equal_approx(difficulty.get_normalized(), 1.0))
	assert(spawn.get_current_ground_limit() == spawn.balance.maximum_ground_enemies)
	assert(is_equal_approx(
		spawn.get_current_spawn_interval(),
		spawn.balance.minimum_spawn_interval
	))

	game_flow.end_run(&"test_restart")
	game_flow.start_run()
	await process_frame
	assert(is_equal_approx(difficulty.get_elapsed_seconds(), 0.0))
	assert(is_equal_approx(difficulty.get_normalized(), 0.0))
	assert(spawn.get_current_ground_limit() == spawn.balance.max_ground_enemies)
	assert(is_equal_approx(
		spawn.get_current_spawn_interval(),
		spawn.balance.spawn_interval
	))
	assert(is_equal_approx(
		spawn.get_spawn_remaining(),
		spawn.balance.spawn_interval
	))

	print("Run difficulty progression scenarios passed")
	quit()


func _wait_process_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await process_frame


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await physics_frame
