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
	var spawn: BoardingSpawnDirector = game.get_node(
		"World/BoardingSpawnDirector"
	)
	var registry: BoardingEnemyRegistry = game.get_node(
		"World/BoardingEnemyRegistry"
	)
	spawn.balance.spawn_interval = 999.0
	game_flow.state = GameFlowController.RunState.RUNNING

	await _test_composable_behavior(game_flow, spawn, registry)
	await _test_standard_enemy_contract(spawn, registry)

	print("Special enemy behavior scenarios passed")
	quit()


func _test_composable_behavior(
	game_flow: GameFlowController,
	spawn: BoardingSpawnDirector,
	registry: BoardingEnemyRegistry
) -> void:
	var enemy: BoardingEnemy = spawn.spawn_debug_archetype(&"basic", 1)
	assert(enemy != null)
	var behavior := TestSpecialEnemyBehavior.new()
	behavior.target_domain = EnemyBehaviorComponent.TargetDomain.AIR
	behavior.turret_targetable = true
	behavior.counts_as_ground = false
	behavior.counts_as_climbing = false
	behavior.counts_as_boarded = false
	enemy.attach_special_behavior(behavior, game_flow)

	await _wait_physics_frames(3)
	assert(behavior.tick_count > 0)
	assert(enemy.is_targetable_by_turret())
	assert(registry.get_turret_targets().has(enemy))
	assert(registry.get_ground_count() == 0)
	assert(registry.get_climbing_count() == 0)
	assert(registry.get_boarded_count() == 0)

	var selector := TurretTargetSelector.new()
	var selected: BoardingEnemy = selector.get_nearest_target(
		registry,
		enemy.global_position,
		100.0
	)
	assert(selected == enemy)

	var ticks_before_pause: int = behavior.tick_count
	game_flow.state = GameFlowController.RunState.MANUAL_PAUSE
	await _wait_physics_frames(3)
	assert(behavior.tick_count == ticks_before_pause)
	game_flow.state = GameFlowController.RunState.RUNNING
	await _wait_physics_frames(2)
	assert(behavior.tick_count > ticks_before_pause)

	enemy.kill(&"test_special_cleanup")
	await _wait_physics_frames(3)
	assert(registry.get_active_count() == 0)


func _test_standard_enemy_contract(
	spawn: BoardingSpawnDirector,
	registry: BoardingEnemyRegistry
) -> void:
	var enemy: BoardingEnemy = spawn.spawn_debug_on_platform(0.0, &"basic")
	assert(enemy != null)
	assert(enemy.behavior == null)
	assert(enemy.is_counted_as_boarded())
	assert(enemy.is_targetable_by_turret())
	assert(registry.get_boarded_enemies().has(enemy))
	enemy.kill(&"test_standard_cleanup")
	await _wait_physics_frames(3)
	assert(registry.get_active_count() == 0)


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await physics_frame
