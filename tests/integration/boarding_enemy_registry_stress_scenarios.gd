extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")
const ENEMY_COUNT: int = 60
const SCAN_ITERATIONS: int = 240
const MAX_SCAN_USEC: int = 800000


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	flow.state = GameFlowController.RunState.RUNNING
	_stabilize_world(game)

	var spawn: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	var registry: BoardingEnemyRegistry = game.get_node("World/BoardingEnemyRegistry")
	for index: int in range(ENEMY_COUNT):
		var side: int = -1 if index % 2 == 0 else 1
		var enemy: BoardingEnemy = spawn.spawn_debug_archetype(&"basic", side)
		assert(enemy != null)
		enemy.controller.set_physics_process(false)
		enemy.set_physics_process(false)
	await process_frame

	assert(registry.get_active_count() == ENEMY_COUNT)
	assert(registry.get_all_enemies().size() == ENEMY_COUNT)
	var generation_after_spawn: int = registry.get_cache_generation()
	assert(generation_after_spawn == ENEMY_COUNT)

	var first_snapshot: Array[BoardingEnemy] = registry.get_all_enemies()
	var second_snapshot: Array[BoardingEnemy] = registry.get_all_enemies()
	assert(first_snapshot.size() == ENEMY_COUNT)
	assert(second_snapshot.size() == ENEMY_COUNT)
	assert(registry.get_cache_generation() == generation_after_spawn)

	var started: int = Time.get_ticks_usec()
	for _iteration: int in range(SCAN_ITERATIONS):
		assert(registry.get_active_count() == ENEMY_COUNT)
		assert(registry.get_ground_count() == ENEMY_COUNT)
		assert(registry.get_archetype_count(&"basic") == ENEMY_COUNT)
		assert(not registry.get_archetype_summary().is_empty())
	var elapsed: int = Time.get_ticks_usec() - started
	assert(elapsed <= MAX_SCAN_USEC)

	var victim: BoardingEnemy = registry.get_enemy(0)
	assert(victim != null)
	victim.kill(&"stress_test")
	await process_frame
	assert(registry.get_active_count() == ENEMY_COUNT - 1)
	assert(registry.get_cache_generation() == generation_after_spawn + 1)
	assert(registry.get_enemy(0) == null)

	print("Boarding enemy registry stress scenarios passed")
	quit()


func _stabilize_world(game: Node) -> void:
	var paths: Array[NodePath] = [
		NodePath("World/BoardingSpawnDirector"),
		NodePath("World/FlyingEnemySpawnDirector"),
		NodePath("World/StrategicWaveSystem"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
	]
	for path: NodePath in paths:
		if not game.has_node(path):
			continue
		var system: Node = game.get_node(path)
		system.set_process(false)
		system.set_physics_process(false)
