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

	var anchors: CombatAnchorHostSystem = game.get_node("World/AnchorSystem")
	var combat: CombatAnchorSystem = game.get_node("World/CombatAnchorSystem")
	var platform: PlatformController = game.get_node("World/Platform")
	var orbs: GroundOrbRegistry = game.get_node("World/GroundOrbRegistry")
	var spawn: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	var rewards: BoardingRewardController = game.get_node(
		"World/BoardingRewardController"
	)
	var visual: CombatAnchorVisualController = anchors.get_node(
		"AnchorVisualController"
	) as CombatAnchorVisualController
	var catalog: UpgradeCatalog = game.get_node("UpgradeSystem").catalog
	assert(anchors != null)
	assert(combat != null)
	assert(visual != null)
	assert(catalog != null)
	anchors.set_physics_process(false)
	combat.set_physics_process(false)

	var events: Array[Dictionary] = []
	combat.trap_triggered.connect(func(
		anchor_id: int,
		world_position: Vector2,
		radius: float,
		damaged_count: int,
		source_id: StringName
	) -> void:
		events.append({
			"anchor": anchor_id,
			"position": world_position,
			"radius": radius,
			"damaged": damaged_count,
			"source": source_id,
		})
	)
	var reward_count: int = 0
	rewards.reward_granted.connect(func(
		_enemy_id: int,
		_amount: int,
		_reason: StringName
	) -> void:
		reward_count += 1
	)

	assert(combat.apply_upgrade_effect(catalog.get_definition(
		&"anchor_specialization_trap"
	).effect))
	assert(combat.apply_upgrade_effect(catalog.get_definition(
		&"anchor_trap_attach_explosion"
	).effect))

	platform.position.x = orbs.get_world_x(2)
	var ground_target: BoardingEnemy = spawn.spawn_debug_archetype(&"basic", 1)
	ground_target.controller.set_physics_process(false)
	ground_target.set_physics_process(false)
	ground_target.global_position = orbs.get_orb_world_position(2)

	anchors.toggle_anchor(0)
	anchors._physics_process(anchors.balance.install_duration + 0.1)
	assert(events.size() == 1)
	assert(events[0]["source"] == &"anchor_trap_attach")
	assert(int(events[0]["damaged"]) == 1)
	assert(is_equal_approx(float(events[0]["radius"]), combat.balance.trap_attach_radius))
	assert(not ground_target.health.is_alive())
	assert(reward_count == 1)
	assert(visual.get_active_trap_burst_count() == 1)
	assert(visual.get_latest_trap_burst_position().distance_to(
		events[0]["position"] as Vector2
	) <= 0.01)
	assert(is_equal_approx(
		visual.get_latest_trap_burst_radius(),
		combat.balance.trap_attach_radius
	))

	var boarded_target: BoardingEnemy = spawn.spawn_debug_on_platform(
		anchors.get_platform_attachment_world(0).x - platform.global_position.x,
		&"basic"
	)
	boarded_target.controller.set_physics_process(false)
	boarded_target.set_physics_process(false)
	anchors._on_anchor_detaching(0)
	assert(events.size() == 2)
	assert(events[1]["source"] == &"anchor_trap_remove")
	assert(int(events[1]["damaged"]) == 1)
	assert(not boarded_target.health.is_alive())
	assert(reward_count == 2)
	assert(visual.get_active_trap_burst_count() == 2)
	assert(is_equal_approx(
		visual.get_latest_trap_burst_radius(),
		combat.balance.trap_remove_radius
	))

	combat.reset_upgrade_runtime()
	var plain_target: BoardingEnemy = spawn.spawn_debug_on_platform(
		anchors.get_platform_attachment_world(0).x - platform.global_position.x,
		&"basic"
	)
	plain_target.controller.set_physics_process(false)
	plain_target.set_physics_process(false)
	anchors._on_anchor_detaching(0)
	assert(events.size() == 2)
	assert(plain_target.health.is_alive())

	print("Combat anchor trap burst scenarios passed")
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
