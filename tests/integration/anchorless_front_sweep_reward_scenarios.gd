extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run_scenario")


func _run_scenario() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	flow.state = GameFlowController.RunState.RUNNING

	var anchorless: AnchorlessControlSystem = game.get_node(
		"World/AnchorlessControlSystem"
	)
	var platform: PlatformController = game.get_node("World/Platform")
	var spawn: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	var flying_spawn: FlyingEnemySpawnDirector = game.get_node(
		"World/FlyingEnemySpawnDirector"
	)
	var registry: BoardingEnemyRegistry = game.get_node(
		"World/BoardingEnemyRegistry"
	)
	var economy: RunEconomy = game.get_node("RunEconomy")
	var upgrade_system: UpgradeSystem = game.get_node("UpgradeSystem")
	var catalog: UpgradeCatalog = upgrade_system.catalog
	anchorless.set_physics_process(false)
	spawn.set_physics_process(false)
	flying_spawn.set_physics_process(false)

	anchorless.reset_upgrade_runtime()
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_specialization_speed"
	).effect))
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_speed_front_sweep"
	).effect))

	var enemy: BoardingEnemy = spawn.spawn_debug_archetype(&"basic", 1)
	enemy.controller.set_physics_process(false)
	enemy.health.set_incoming_damage_multiplier(0.1)
	var enemy_id: int = enemy.enemy_id
	platform.horizontal_velocity = 1.0
	var leading_edge_x: float = (
		platform.global_position.x + platform.get_platform_width() * 0.5
	)
	enemy.global_position = Vector2(leading_edge_x + 10.0, 510.0)
	var coins_before: int = economy.get_coins()
	assert(registry.get_enemy(enemy_id) == enemy)

	anchorless._physics_process(0.1)
	assert(registry.get_enemy(enemy_id) == null)
	assert(economy.get_coins() == coins_before + 1)
	print("Anchorless front sweep reward scenarios passed")
	quit()
