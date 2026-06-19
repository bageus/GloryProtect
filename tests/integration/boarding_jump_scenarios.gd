extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	await _test_no_jump_without_enemy_blocker()
	await _test_jump_over_defender_when_landing_is_free()
	await _test_no_jump_when_landing_is_occupied()
	print("Boarding jump scenarios passed")
	quit()


func _test_no_jump_without_enemy_blocker() -> void:
	var game: Node2D = await _create_prepared_game()
	var spawn: BoardingSpawnDirector = game.get_node(
		"World/BoardingSpawnDirector"
	)
	var enemy: BoardingEnemy = spawn.spawn_debug_on_platform(-56.0)
	enemy.melee.configure(1, 10.0, 1.0)

	var jumped: bool = await _observe_jump(enemy, 90)
	assert(not jumped)
	assert(enemy.controller.get_platform_local_x() < 0.0)

	game.queue_free()
	await process_frame


func _test_jump_over_defender_when_landing_is_free() -> void:
	var game: Node2D = await _create_prepared_game()
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var spawn: BoardingSpawnDirector = game.get_node(
		"World/BoardingSpawnDirector"
	)
	var target: Defender = crew.get_defender(0)

	var front_enemy: BoardingEnemy = spawn.spawn_debug_on_platform(-28.0)
	front_enemy.melee.configure(1, 10.0, 1.0)
	var jumping_enemy: BoardingEnemy = spawn.spawn_debug_on_platform(-56.0)
	jumping_enemy.melee.configure(1, 10.0, 1.0)

	var jumped: bool = await _observe_jump(jumping_enemy, 60)
	assert(jumped)
	await _wait_until_jump_finished(jumping_enemy, 90)

	assert(jumping_enemy.controller.get_platform_local_x() > target.position.x)
	assert(jumping_enemy.get_state() == BoardingEnemyController.State.FIGHTING)
	assert(
		absf(
			jumping_enemy.controller.get_platform_local_x()
			- target.position.x
		) <= spawn.balance.enemy_attack_range
	)

	game.queue_free()
	await process_frame


func _test_no_jump_when_landing_is_occupied() -> void:
	var game: Node2D = await _create_prepared_game()
	var spawn: BoardingSpawnDirector = game.get_node(
		"World/BoardingSpawnDirector"
	)

	var front_enemy: BoardingEnemy = spawn.spawn_debug_on_platform(-28.0)
	front_enemy.melee.configure(1, 10.0, 1.0)
	var landing_blocker: BoardingEnemy = spawn.spawn_debug_on_platform(28.0)
	landing_blocker.melee.configure(1, 10.0, 1.0)
	var waiting_enemy: BoardingEnemy = spawn.spawn_debug_on_platform(-56.0)
	waiting_enemy.melee.configure(1, 10.0, 1.0)

	var jumped: bool = await _observe_jump(waiting_enemy, 90)
	assert(not jumped)
	assert(waiting_enemy.controller.get_platform_local_x() < 0.0)

	game.queue_free()
	await process_frame


func _create_prepared_game() -> Node2D:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var game_flow: GameFlowController = game.get_node("GameFlowController")
	var wind: WindSystem = game.get_node("WindSystem")
	var platform: PlatformController = game.get_node("World/Platform")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var spawn: BoardingSpawnDirector = game.get_node(
		"World/BoardingSpawnDirector"
	)

	game_flow.state = GameFlowController.RunState.RUNNING
	wind.balance.level_forces = PackedFloat32Array([0.0, 0.0, 0.0])
	wind.balance.fluctuation_force = 0.0
	wind.set_debug_state(1, 1)
	platform.position.x = 0.0
	platform.horizontal_velocity = 0.0
	spawn.balance.spawn_interval = 999.0

	var target: Defender = crew.get_defender(0)
	var left_defender: Defender = crew.get_defender(1)
	var right_defender: Defender = crew.get_defender(2)
	target.teleport_to(0.0)
	left_defender.teleport_to(-300.0)
	right_defender.teleport_to(300.0)
	for defender: Defender in crew.get_living_defenders():
		defender.melee.configure(1, 10.0, 1.0)

	return game


func _observe_jump(
	enemy: BoardingEnemy,
	frame_count: int
) -> bool:
	for _frame: int in range(frame_count):
		if enemy.get_state() == BoardingEnemyController.State.JUMPING:
			return true
		await physics_frame
	return false


func _wait_until_jump_finished(
	enemy: BoardingEnemy,
	max_frames: int
) -> void:
	for _frame: int in range(max_frames):
		if enemy.get_state() != BoardingEnemyController.State.JUMPING:
			return
		await physics_frame
	assert(false, "Enemy did not finish jump")
