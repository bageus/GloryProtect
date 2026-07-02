extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


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

	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var roles: CrewRoleManager = game.get_node("World/Platform/CrewRoleManager")
	var resolver: BoardingMovementResolver = game.get_node(
		"World/BoardingMovementResolver"
	)
	var spawn: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	assert(crew != null)
	assert(roles != null)
	assert(resolver != null)

	var test_enemy: BoardingEnemy = spawn.spawn_debug_archetype(&"brute", 1)
	assert(test_enemy != null)
	test_enemy.controller.set_physics_process(false)
	test_enemy.set_physics_process(false)

	for defender_id: int in [0, 1, 2]:
		var defender: Defender = crew.get_defender(defender_id)
		var assignment: CrewAssignmentRuntime = roles.get_assignment(defender_id)
		assert(defender != null)
		assert(assignment != null)
		assert(assignment.state == CrewAssignmentRuntime.State.ACTIVE)
		assert(CrewRole.is_fixed_station(assignment.current_role))
		assert(not resolver.is_defender_platform_obstacle(defender))
		assert(resolver.can_place_enemy_at(test_enemy, defender.position.x))
		var cross_result: float = resolver.resolve_enemy_platform_x(
			test_enemy,
			defender.position.x - 80.0,
			defender.position.x + 80.0
		)
		assert(cross_result > defender.position.x)
		assert(roles.get_assignment(defender_id).current_role == assignment.current_role)

	var free_defender: Defender = crew.add_defender(0.0)
	await process_frame
	await process_frame
	assert(free_defender != null)
	var free_assignment: CrewAssignmentRuntime = roles.get_assignment(
		free_defender.defender_id
	)
	assert(free_assignment != null)
	assert(free_assignment.current_role == CrewRole.Id.FREE_FIGHTER)
	assert(resolver.is_defender_platform_obstacle(free_defender))
	var blocked_result: float = resolver.resolve_enemy_platform_x(
		test_enemy,
		free_defender.position.x - 80.0,
		free_defender.position.x + 80.0
	)
	assert(blocked_result <= free_defender.position.x)

	var driver: Defender = crew.get_defender(0)
	var nearest: Defender = crew.get_nearest_living_defender(driver.global_position)
	assert(nearest == driver)
	var health_before: int = driver.health.current_health
	driver.health.apply_damage(1, &"post_operator_pathing_test")
	assert(driver.health.current_health == health_before - 1)
	assert(roles.get_assignment(driver.defender_id).current_role == CrewRole.Id.DRIVER)

	print("Post operator pathing scenarios passed")
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
