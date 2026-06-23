extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	flow.state = GameFlowController.RunState.RUNNING
	_stabilize_world(game)

	var anchorless: AnchorlessControlSystem = game.get_node(
		"World/AnchorlessControlSystem"
	)
	var platform: PlatformController = game.get_node("World/Platform")
	var contact: OrbContactSystem = game.get_node("World/OrbContactSystem")
	var spawn: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	var flying_spawn: FlyingEnemySpawnDirector = game.get_node(
		"World/FlyingEnemySpawnDirector"
	)
	var orbs: GroundOrbRegistry = game.get_node("World/GroundOrbRegistry")
	var upgrade_system: UpgradeSystem = game.get_node("UpgradeSystem")
	var catalog: UpgradeCatalog = upgrade_system.catalog
	anchorless.set_physics_process(false)
	contact.set_physics_process(false)

	await _test_anchor_discharge(anchorless, contact, spawn, catalog)
	await _test_core_pulses(
		anchorless,
		platform,
		contact,
		spawn,
		flying_spawn,
		orbs,
		catalog
	)
	await _test_front_sweep(anchorless, platform, spawn, catalog)

	print("Anchorless specialization combat scenarios passed")
	quit()


func _test_anchor_discharge(
	anchorless: AnchorlessControlSystem,
	contact: OrbContactSystem,
	spawn: BoardingSpawnDirector,
	catalog: UpgradeCatalog
) -> void:
	anchorless.reset_upgrade_runtime()
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_specialization_powerful"
	).effect))
	var enemy: BoardingEnemy = spawn.spawn_debug_archetype(&"brute", 1)
	enemy.controller.set_physics_process(false)
	enemy.global_position = Vector2(120.0, 510.0)
	anchorless._last_anchor_points[AnchorRuntime.Side.LEFT] = enemy.global_position
	contact.active_orb_id = -1
	contact._set_active_orb(2)
	assert(enemy.health.current_health == enemy.health.max_health - 1)
	enemy.kill(&"test_cleanup")
	await process_frame


func _test_core_pulses(
	anchorless: AnchorlessControlSystem,
	platform: PlatformController,
	contact: OrbContactSystem,
	spawn: BoardingSpawnDirector,
	flying_spawn: FlyingEnemySpawnDirector,
	orbs: GroundOrbRegistry,
	catalog: UpgradeCatalog
) -> void:
	anchorless.reset_upgrade_runtime()
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_specialization_powerful"
	).effect))
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_powerful_ground_core"
	).effect))
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_powerful_platform_core"
	).effect))
	platform.position.x = orbs.get_world_x(2)

	var ground: BoardingEnemy = spawn.spawn_debug_archetype(&"brute", 1)
	ground.controller.set_physics_process(false)
	ground.global_position = orbs.get_orb_world_position(2)

	var boarded: BoardingEnemy = spawn.spawn_debug_on_platform(0.0, &"brute")
	boarded.controller.set_physics_process(false)

	var flying_on_connect: BoardingEnemy = flying_spawn.spawn_now(1)
	flying_on_connect.behavior.set_physics_process(false)
	flying_on_connect.global_position = platform.global_position + Vector2(0.0, -40.0)

	var climbing: BoardingEnemy = spawn.spawn_debug_archetype(&"brute", 1)
	climbing.controller.set_physics_process(false)
	climbing.controller.state = BoardingEnemyController.State.CLIMBING
	climbing.global_position = platform.global_position + Vector2(0.0, 40.0)

	contact.active_orb_id = -1
	contact._set_active_orb(2)
	assert(ground.health.current_health == ground.health.max_health - 2)
	assert(boarded.health.current_health == boarded.health.max_health - 2)
	assert(not flying_on_connect.health.is_alive())
	assert(climbing.health.current_health == climbing.health.max_health)

	var flying_on_disconnect: BoardingEnemy = flying_spawn.spawn_now(-1)
	flying_on_disconnect.behavior.set_physics_process(false)
	flying_on_disconnect.global_position = (
		platform.global_position + Vector2(0.0, -40.0)
	)
	contact._set_active_orb(-1)
	assert(not ground.health.is_alive())
	assert(not boarded.health.is_alive())
	assert(not flying_on_disconnect.health.is_alive())
	assert(climbing.health.current_health == climbing.health.max_health)

	ground.kill(&"test_cleanup")
	boarded.kill(&"test_cleanup")
	flying_on_connect.kill(&"test_cleanup")
	flying_on_disconnect.kill(&"test_cleanup")
	climbing.kill(&"test_cleanup")
	await process_frame


func _test_front_sweep(
	anchorless: AnchorlessControlSystem,
	platform: PlatformController,
	spawn: BoardingSpawnDirector,
	catalog: UpgradeCatalog
) -> void:
	anchorless.reset_upgrade_runtime()
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_specialization_speed"
	).effect))
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_speed_front_sweep"
	).effect))
	var first: BoardingEnemy = spawn.spawn_debug_archetype(&"basic", 1)
	var second: BoardingEnemy = spawn.spawn_debug_archetype(&"basic", 1)
	first.controller.set_physics_process(false)
	second.controller.set_physics_process(false)
	platform.horizontal_velocity = anchorless.balance.front_sweep_minimum_speed + 1.0
	var leading_edge_x: float = (
		platform.global_position.x + platform.get_platform_width() * 0.5
	)
	first.global_position = Vector2(leading_edge_x + 10.0, 510.0)
	second.global_position = Vector2(leading_edge_x + 30.0, 510.0)
	anchorless._physics_process(0.1)
	assert(not first.health.is_alive())
	assert(not second.health.is_alive())
	await process_frame


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
