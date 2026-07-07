extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame
	_disable_spawners(game)
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.state = GameFlowController.RunState.RUNNING
	paused = false

	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var spawner: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	var resolver: BoardingMovementResolver = game.get_node(
		"World/BoardingMovementResolver"
	)

	var driver: Defender = crew.get_defender(0)
	assert(driver != null)
	var driver_enemy: BoardingEnemy = _spawn_boarded_enemy(
		spawner,
		driver.position.x + 8.0
	)
	driver.health.apply_damage(1, &"melee", driver_enemy)
	await physics_frame
	assert(driver.combat.get_retaliation_target_for_tests() == driver_enemy)
	assert(driver.melee.is_attacking())
	assert(driver.is_combat_action_active())

	var replacement: Defender = crew.add_defender(driver.position.x - 96.0)
	await process_frame
	await process_frame
	assert(replacement != null)
	replacement.move_to(driver.position.x + 160.0)
	var attacker: BoardingEnemy = _spawn_boarded_enemy(
		spawner,
		replacement.position.x - 8.0
	)
	replacement.health.apply_damage(1, &"melee", attacker)
	await physics_frame
	assert(replacement.combat.get_retaliation_target_for_tests() == attacker)
	assert(replacement.melee.is_attacking())

	var passer: Defender = crew.add_defender(driver.position.x - 160.0)
	await process_frame
	await process_frame
	assert(passer != null)
	var busy_enemy: BoardingEnemy = _spawn_boarded_enemy(
		spawner,
		passer.position.x + 40.0
	)
	var blocked_x: float = resolver.resolve_defender_platform_x(
		passer,
		passer.position.x,
		busy_enemy.controller.get_platform_occupancy_x() + 64.0
	)
	assert(blocked_x <= busy_enemy.controller.get_platform_occupancy_x())
	busy_enemy.controller.state = BoardingEnemyController.State.FIGHTING
	assert(resolver.can_defender_pass_enemy_for_tests(passer, busy_enemy))
	var pass_x: float = resolver.resolve_defender_platform_x(
		passer,
		passer.position.x,
		busy_enemy.controller.get_platform_occupancy_x() + 64.0
	)
	assert(pass_x > busy_enemy.controller.get_platform_occupancy_x())

	print("Defender attack queue scenarios passed")
	quit()


func _spawn_boarded_enemy(
	spawner: BoardingSpawnDirector,
	local_x: float
) -> BoardingEnemy:
	var enemy: BoardingEnemy = spawner.spawn_debug_on_platform(local_x, &"basic")
	assert(enemy != null)
	enemy.force_board_at(local_x)
	return enemy


func _disable_spawners(game: Node) -> void:
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
		var node: Node = game.get_node(path)
		node.set_process(false)
		node.set_physics_process(false)
