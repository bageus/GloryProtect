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
	var economy: RunEconomy = game.get_node("RunEconomy")
	var platform: PlatformController = game.get_node("World/Platform")
	var wind: WindSystem = game.get_node("WindSystem")
	var anchors: AnchorSystem = game.get_node("World/AnchorSystem")
	var paths: AnchorPathRegistry = game.get_node("World/AnchorPathRegistry")
	var enemies: BoardingEnemyRegistry = game.get_node("World/BoardingEnemyRegistry")
	var spawn: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var reward: int = economy.balance.boarding_enemy_base_reward

	game_flow.state = GameFlowController.RunState.RUNNING
	wind.balance.level_forces = PackedFloat32Array([0.0, 0.0, 0.0])
	wind.balance.fluctuation_force = 0.0
	wind.set_debug_state(1, 1)
	platform.position.x = 0.0
	platform.horizontal_velocity = 0.0

	assert(economy.get_coins() == 0)
	assert(spawn.spawn_now() == null)
	assert(paths.get_available_count() == 0)

	anchors.toggle_anchor(2)
	await _wait_physics_frames(90)
	assert(paths.get_available_count() == 1)
	var path: AnchorPathSnapshot = paths.get_available_paths()[0]

	var climbing_enemy: BoardingEnemy = spawn.spawn_now()
	assert(climbing_enemy != null)
	climbing_enemy.global_position = path.ground_point
	await _wait_physics_frames(3)
	assert(
		climbing_enemy.get_state() == BoardingEnemyController.State.CLIMBING
	)

	anchors.toggle_anchor(path.anchor_id)
	await _wait_physics_frames(2)
	assert(enemies.get_active_count() == 0)
	assert(economy.get_coins() == reward)

	anchors.toggle_anchor(2)
	await _wait_physics_frames(90)
	assert(paths.get_available_count() == 1)

	var boarded_survivor: BoardingEnemy = spawn.spawn_debug_on_platform(250.0)
	assert(boarded_survivor.is_on_platform())
	anchors.toggle_anchor(2)
	await _wait_physics_frames(1)
	assert(is_instance_valid(boarded_survivor))
	assert(boarded_survivor.health.is_alive())
	assert(boarded_survivor.is_on_platform())
	boarded_survivor.kill(&"test_cleanup")
	await _wait_physics_frames(1)
	assert(economy.get_coins() == reward)

	var driver: Defender = crew.get_defender(0)
	var driver_health_before: int = driver.health.current_health
	var attacking_enemy: BoardingEnemy = spawn.spawn_debug_on_platform(0.0)
	await _wait_physics_frames(40)
	assert(driver.health.current_health < driver_health_before)
	assert(is_instance_valid(attacking_enemy))
	attacking_enemy.kill(&"test_cleanup")
	await _wait_physics_frames(1)
	assert(economy.get_coins() == reward)

	var left_anchor_defender: Defender = crew.get_defender(1)
	var defender_local_x: float = left_anchor_defender.position.x
	var doomed_enemy: BoardingEnemy = spawn.spawn_debug_on_platform(
		defender_local_x + 20.0
	)
	await _wait_physics_frames(35)
	assert(not is_instance_valid(doomed_enemy) or not doomed_enemy.health.is_alive())
	assert(economy.get_coins() == reward * 2)

	print("Boarding enemy scenarios passed")
	quit()


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await physics_frame
