extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var game_flow: GameFlowController = game.get_node("GameFlowController")
	var director: FlyingEnemySpawnDirector = game.get_node(
		"World/FlyingEnemySpawnDirector"
	)
	var registry: BoardingEnemyRegistry = game.get_node(
		"World/BoardingEnemyRegistry"
	)
	var platform: PlatformController = game.get_node("World/Platform")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	game_flow.state = GameFlowController.RunState.RUNNING
	director.profile.spawn_interval = 999.0

	await _test_flight_without_anchors(director, registry, platform)
	await _test_landing_before_melee(director, registry, platform, crew)
	await _test_pause_stops_flight(game_flow, director)
	await _test_turret_contract(director, registry)
	await _test_shared_death_flow(director, registry)
	await _test_air_separation(director)

	print("Flying enemy scenarios passed")
	quit()


func _test_flight_without_anchors(
	director: FlyingEnemySpawnDirector,
	registry: BoardingEnemyRegistry,
	platform: PlatformController
) -> void:
	var enemy: BoardingEnemy = director.spawn_now(1)
	assert(enemy != null)
	assert(enemy.behavior is FlyingEnemyBehavior)
	assert(registry.get_ground_count() == 0)
	assert(registry.get_climbing_count() == 0)
	assert(registry.get_boarded_count() == 0)
	var start_distance: float = enemy.global_position.distance_to(
		platform.global_position
	)
	await _wait_physics_frames(20)
	var end_distance: float = enemy.global_position.distance_to(
		platform.global_position
	)
	assert(end_distance < start_distance)
	enemy.kill(&"test_cleanup")
	await _wait_physics_frames(3)


func _test_landing_before_melee(
	director: FlyingEnemySpawnDirector,
	registry: BoardingEnemyRegistry,
	platform: PlatformController,
	crew: CrewManager
) -> void:
	var target: Defender = crew.get_defender(0)
	var enemy: BoardingEnemy = director.spawn_now(1)
	var behavior := enemy.behavior as FlyingEnemyBehavior
	assert(behavior != null)
	var health_before: int = target.health.current_health
	enemy.global_position = Vector2(
		target.global_position.x,
		platform.global_position.y - director.profile.hover_height
	)
	await physics_frame
	assert(behavior.state == FlyingEnemyBehavior.State.LANDING)
	assert(not behavior.is_landed())
	assert(not enemy.is_counted_as_boarded())
	assert(target.health.current_health == health_before)

	for _frame: int in range(180):
		if behavior.is_landed():
			break
		await physics_frame
	assert(behavior.is_landed())
	assert(enemy.is_counted_as_boarded())
	assert(enemy.get_target_domain() == EnemyBehaviorComponent.TargetDomain.GROUND)
	assert(registry.get_boarded_count() == 1)

	for _frame: int in range(180):
		if target.health.current_health < health_before:
			break
		await physics_frame
	assert(target.health.current_health < health_before)
	enemy.kill(&"test_cleanup")
	await _wait_physics_frames(3)


func _test_pause_stops_flight(
	game_flow: GameFlowController,
	director: FlyingEnemySpawnDirector
) -> void:
	var enemy: BoardingEnemy = director.spawn_now(-1)
	assert(enemy != null)
	await _wait_physics_frames(4)
	game_flow.state = GameFlowController.RunState.MANUAL_PAUSE
	var paused_position: Vector2 = enemy.global_position
	await _wait_physics_frames(8)
	assert(enemy.global_position.is_equal_approx(paused_position))
	game_flow.state = GameFlowController.RunState.RUNNING
	await _wait_physics_frames(4)
	assert(not enemy.global_position.is_equal_approx(paused_position))
	enemy.kill(&"test_cleanup")
	await _wait_physics_frames(3)


func _test_turret_contract(
	director: FlyingEnemySpawnDirector,
	registry: BoardingEnemyRegistry
) -> void:
	var enemy: BoardingEnemy = director.spawn_now(1)
	assert(enemy.is_targetable_by_turret())
	assert(registry.get_turret_targets().has(enemy))
	var selector := TurretTargetSelector.new()
	var selected: BoardingEnemy = selector.get_nearest_target(
		registry,
		enemy.global_position,
		100.0
	)
	assert(selected == enemy)
	enemy.kill(&"test_cleanup")
	await _wait_physics_frames(3)


func _test_shared_death_flow(
	director: FlyingEnemySpawnDirector,
	registry: BoardingEnemyRegistry
) -> void:
	var enemy: BoardingEnemy = director.spawn_now(1)
	var enemy_id: int = enemy.enemy_id
	assert(registry.get_enemy(enemy_id) == enemy)
	enemy.health.apply_damage(enemy.health.max_health)
	await _wait_physics_frames(3)
	assert(registry.get_enemy(enemy_id) == null)


func _test_air_separation(director: FlyingEnemySpawnDirector) -> void:
	var first: BoardingEnemy = director.spawn_now(1)
	var second: BoardingEnemy = director.spawn_now(1)
	second.global_position = first.global_position + Vector2(2.0, 0.0)
	var start_distance: float = first.global_position.distance_to(
		second.global_position
	)
	await _wait_physics_frames(12)
	var end_distance: float = first.global_position.distance_to(
		second.global_position
	)
	assert(end_distance > start_distance)
	first.kill(&"test_cleanup")
	second.kill(&"test_cleanup")
	await _wait_physics_frames(3)


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await physics_frame
