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

	var platform: PlatformController = game.get_node("World/Platform")
	var wind: WindSystem = game.get_node("WindSystem")
	var anchors: CombatAnchorHostSystem = game.get_node("World/AnchorSystem")
	var combat: CombatAnchorSystem = game.get_node("World/CombatAnchorSystem")
	var director: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	var registry: BoardingEnemyRegistry = game.get_node("World/BoardingEnemyRegistry")
	var economy: RunEconomy = game.get_node("RunEconomy")
	combat.set_physics_process(false)
	wind.balance.level_forces = PackedFloat32Array([0.0, 0.0, 0.0])
	wind.balance.fluctuation_force = 0.0
	wind.set_debug_state(1, 1)
	platform.position.x = 0.0
	platform.horizontal_velocity = 0.0

	anchors.toggle_anchor(2)
	assert(await _wait_for_path(anchors, 2))
	var initial_path: AnchorPathSnapshot = anchors.get_path_snapshot(2)
	assert(initial_path != null)
	var ground_point: Vector2 = initial_path.ground_point
	anchors.toggle_anchor(2)
	assert(anchors.get_anchor_state(2) == AnchorRuntime.State.STOWED)

	await _test_periodic_electricity(
		anchors,
		combat,
		director,
		ground_point
	)
	await _test_electric_specialization(
		anchors,
		combat,
		director,
		registry,
		economy,
		ground_point
	)
	await _test_trap_specialization(
		anchors,
		combat,
		director,
		registry,
		platform,
		ground_point
	)
	await _test_strong_fall(
		anchors,
		combat,
		director,
		registry,
		economy
	)

	print("Combat anchor specialization scenarios passed")
	quit()


func _test_periodic_electricity(
	anchors: CombatAnchorHostSystem,
	combat: CombatAnchorSystem,
	director: BoardingSpawnDirector,
	_ground_point: Vector2
) -> void:
	combat.reset_upgrade_runtime()
	assert(combat.apply_upgrade_effect(_flag(
		CombatAnchorUpgradeRuntime.PERIODIC_ELECTRIC
	)))
	anchors.toggle_anchor(2)
	assert(await _wait_for_path(anchors, 2))
	var path: AnchorPathSnapshot = anchors.get_path_snapshot(2)
	var enemy: BoardingEnemy = _spawn_climber(director, path, 2, 5)
	combat.call("_physics_process", 4.0)
	assert(enemy.health.current_health == 4)
	assert(combat.apply_upgrade_effect(_flag(
		CombatAnchorUpgradeRuntime.PERIODIC_ELECTRIC_ADVANCED
	)))
	assert(is_equal_approx(combat.get_periodic_interval(), 2.0))
	combat.call("_physics_process", 2.0)
	assert(enemy.health.current_health == 3)
	enemy.kill(&"test_cleanup")
	anchors.toggle_anchor(2)
	assert(anchors.get_anchor_state(2) == AnchorRuntime.State.STOWED)


func _test_electric_specialization(
	anchors: CombatAnchorHostSystem,
	combat: CombatAnchorSystem,
	director: BoardingSpawnDirector,
	registry: BoardingEnemyRegistry,
	economy: RunEconomy,
	ground_point: Vector2
) -> void:
	combat.reset_upgrade_runtime()
	combat.balance.electric_stun_chance = 1.0
	combat.balance.electric_drop_chance = 1.0
	assert(combat.apply_upgrade_effect(_flag(
		CombatAnchorUpgradeRuntime.ELECTRIC
	)))
	assert(combat.apply_upgrade_effect(_flag(
		CombatAnchorUpgradeRuntime.ELECTRIC_DROP
	)))

	var ground_enemy: BoardingEnemy = _spawn_ground_enemy(
		director,
		ground_point,
		5
	)
	anchors.toggle_anchor(2)
	assert(await _wait_for_path(anchors, 2))
	assert(ground_enemy.health.current_health == 4)
	assert(ground_enemy.is_stunned())
	ground_enemy.kill(&"test_cleanup")

	var path: AnchorPathSnapshot = anchors.get_path_snapshot(2)
	var climber: BoardingEnemy = _spawn_climber(director, path, 2, 5)
	var climber_id: int = climber.enemy_id
	var coins_before: int = economy.get_coins()
	anchors.toggle_anchor(2)
	assert(registry.get_enemy(climber_id) == null)
	assert(economy.get_coins() == coins_before + 1)
	assert(anchors.get_anchor_state(2) == AnchorRuntime.State.STOWED)


func _test_trap_specialization(
	anchors: CombatAnchorHostSystem,
	combat: CombatAnchorSystem,
	director: BoardingSpawnDirector,
	registry: BoardingEnemyRegistry,
	platform: PlatformController,
	ground_point: Vector2
) -> void:
	combat.reset_upgrade_runtime()
	assert(combat.apply_upgrade_effect(_flag(
		CombatAnchorUpgradeRuntime.TRAP
	)))
	assert(combat.apply_upgrade_effect(_flag(
		CombatAnchorUpgradeRuntime.TRAP_ATTACH_EXPLOSION
	)))

	var ground_enemy: BoardingEnemy = _spawn_ground_enemy(
		director,
		ground_point,
		5
	)
	anchors.toggle_anchor(2)
	assert(await _wait_for_path(anchors, 2))
	assert(ground_enemy.health.current_health == 4)
	ground_enemy.kill(&"test_cleanup")

	var edge: Vector2 = anchors.get_platform_attachment_world(2)
	var edge_local_x: float = edge.x - platform.global_position.x
	var boarded: BoardingEnemy = director.spawn_debug_on_platform(
		edge_local_x - 60.0,
		&"brute"
	)
	assert(boarded != null)
	boarded.health.configure(5)
	boarded.controller.set_physics_process(false)
	var boarded_id: int = boarded.enemy_id
	var before_x: float = boarded.controller.get_platform_local_x()
	anchors.toggle_anchor(2)
	assert(registry.get_enemy(boarded_id) == boarded)
	assert(boarded.health.current_health == 4)
	assert(not is_equal_approx(
		boarded.controller.get_platform_local_x(),
		before_x
	))
	boarded.kill(&"test_cleanup")
	assert(anchors.get_anchor_state(2) == AnchorRuntime.State.STOWED)


func _test_strong_fall(
	anchors: CombatAnchorHostSystem,
	combat: CombatAnchorSystem,
	director: BoardingSpawnDirector,
	registry: BoardingEnemyRegistry,
	economy: RunEconomy
) -> void:
	combat.reset_upgrade_runtime()
	combat.balance.spontaneous_fall_chance = 1.0
	assert(combat.apply_upgrade_effect(_flag(
		CombatAnchorUpgradeRuntime.STRONG
	)))
	assert(combat.apply_upgrade_effect(_flag(
		CombatAnchorUpgradeRuntime.STRONG_CLIMBER_FALL
	)))
	anchors.toggle_anchor(2)
	assert(await _wait_for_path(anchors, 2))
	var path: AnchorPathSnapshot = anchors.get_path_snapshot(2)
	var enemy: BoardingEnemy = director.spawn_debug_archetype(&"brute", 1)
	assert(enemy != null)
	enemy.health.configure(5)
	enemy.controller.set_physics_process(false)
	enemy.controller.selected_anchor_id = 2
	enemy.controller.state = BoardingEnemyController.State.RUNNING_TO_ANCHOR
	combat.call("_physics_process", 0.0)
	enemy.controller.state = BoardingEnemyController.State.CLIMBING
	enemy.global_position = path.ground_point.lerp(path.platform_point, 0.5)
	var enemy_id: int = enemy.enemy_id
	var coins_before: int = economy.get_coins()
	combat.call("_physics_process", 0.0)
	assert(registry.get_enemy(enemy_id) == null)
	assert(economy.get_coins() == coins_before + 1)


func _spawn_ground_enemy(
	director: BoardingSpawnDirector,
	world_position: Vector2,
	health: int
) -> BoardingEnemy:
	var enemy: BoardingEnemy = director.spawn_debug_archetype(&"brute", 1)
	assert(enemy != null)
	enemy.health.configure(health)
	enemy.controller.set_physics_process(false)
	enemy.controller.state = BoardingEnemyController.State.WAITING_WITHOUT_PATH
	enemy.controller.selected_anchor_id = -1
	enemy.global_position = world_position
	return enemy


func _spawn_climber(
	director: BoardingSpawnDirector,
	path: AnchorPathSnapshot,
	anchor_id: int,
	health: int
) -> BoardingEnemy:
	var enemy: BoardingEnemy = director.spawn_debug_archetype(&"brute", 1)
	assert(enemy != null)
	enemy.health.configure(health)
	enemy.controller.set_physics_process(false)
	enemy.controller.selected_anchor_id = anchor_id
	enemy.controller.state = BoardingEnemyController.State.CLIMBING
	enemy.global_position = path.ground_point.lerp(path.platform_point, 0.5)
	return enemy


func _flag(target_id: StringName) -> UpgradeEffectDefinition:
	var effect := UpgradeEffectDefinition.new()
	effect.effect_type = UpgradeEffectDefinition.EffectType.DOMAIN_FLAG
	effect.target_id = target_id
	return effect


func _wait_for_path(
	anchors: CombatAnchorHostSystem,
	anchor_id: int
) -> bool:
	for _frame: int in range(240):
		if anchors.is_path_available(anchor_id):
			return true
		await physics_frame
	return anchors.is_path_available(anchor_id)


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
