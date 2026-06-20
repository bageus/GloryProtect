extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var game_flow: GameFlowController = game.get_node("GameFlowController")
	var platform: PlatformController = game.get_node("World/Platform")
	var spawn: BoardingSpawnDirector = game.get_node(
		"World/BoardingSpawnDirector"
	)
	var registry: BoardingEnemyRegistry = game.get_node(
		"World/BoardingEnemyRegistry"
	)

	game_flow.state = GameFlowController.RunState.RUNNING
	spawn.balance.spawn_interval = 999.0
	platform.position.x = 0.0
	platform.horizontal_velocity = 0.0

	await _test_profiles(spawn, registry)
	await _test_runner_speed(spawn, platform)
	await _test_large_enemy_separation(spawn)

	print("Boarding enemy archetype scenarios passed")
	quit()


func _test_profiles(
	spawn: BoardingSpawnDirector,
	registry: BoardingEnemyRegistry
) -> void:
	var basic: BoardingEnemy = spawn.spawn_debug_archetype(&"basic", 1)
	var runner: BoardingEnemy = spawn.spawn_debug_archetype(&"runner", -1)
	var brute: BoardingEnemy = spawn.spawn_debug_archetype(&"brute", 1)
	assert(basic != null and runner != null and brute != null)
	assert(basic.get_archetype_id() == &"basic")
	assert(runner.get_archetype_id() == &"runner")
	assert(brute.get_archetype_id() == &"brute")
	assert(basic.health.max_health == 1)
	assert(runner.health.max_health == 1)
	assert(brute.health.max_health == 3)
	assert(runner.get_body_radius() < basic.get_body_radius())
	assert(brute.get_body_radius() > basic.get_body_radius())
	assert(registry.get_archetype_count(&"basic") == 1)
	assert(registry.get_archetype_count(&"runner") == 1)
	assert(registry.get_archetype_count(&"brute") == 1)
	assert(registry.get_archetype_summary() != "НЕТ")

	basic.kill(&"test_cleanup")
	runner.kill(&"test_cleanup")
	brute.kill(&"test_cleanup")
	await _wait_physics_frames(3)
	assert(registry.get_active_count() == 0)


func _test_runner_speed(
	spawn: BoardingSpawnDirector,
	platform: PlatformController
) -> void:
	var basic: BoardingEnemy = spawn.spawn_debug_archetype(&"basic", 1)
	assert(basic != null)
	var basic_start_distance: float = absf(
		basic.global_position.x - platform.global_position.x
	)
	await _wait_physics_frames(30)
	var basic_travel: float = basic_start_distance - absf(
		basic.global_position.x - platform.global_position.x
	)
	basic.kill(&"test_cleanup")
	await _wait_physics_frames(3)

	var runner: BoardingEnemy = spawn.spawn_debug_archetype(&"runner", 1)
	assert(runner != null)
	var runner_start_distance: float = absf(
		runner.global_position.x - platform.global_position.x
	)
	await _wait_physics_frames(30)
	var runner_travel: float = runner_start_distance - absf(
		runner.global_position.x - platform.global_position.x
	)
	assert(runner_travel > basic_travel * 1.25)
	runner.kill(&"test_cleanup")
	await _wait_physics_frames(3)


func _test_large_enemy_separation(spawn: BoardingSpawnDirector) -> void:
	var first: BoardingEnemy = spawn.spawn_debug_on_platform(180.0, &"brute")
	var second: BoardingEnemy = spawn.spawn_debug_on_platform(180.0, &"brute")
	assert(first != null and second != null)
	first.melee.configure(1, 10.0, 10.0)
	second.melee.configure(1, 10.0, 10.0)
	await _wait_physics_frames(4)
	var distance: float = absf(
		first.controller.get_platform_local_x()
		- second.controller.get_platform_local_x()
	)
	var required_gap: float = first.get_body_radius() + second.get_body_radius()
	assert(required_gap > spawn.balance.platform_enemy_spacing)
	assert(distance >= required_gap - 0.5)
	first.kill(&"test_cleanup")
	second.kill(&"test_cleanup")
	await _wait_physics_frames(3)


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await physics_frame
