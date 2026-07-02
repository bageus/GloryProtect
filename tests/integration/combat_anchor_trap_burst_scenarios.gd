extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")
const TAIL := "trap"
const ANCHOR_ID: int = 2


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
	assert(platform != null)

	var events: Array[Dictionary] = []
	combat.connect(StringName(TAIL + "_triggered"), func(
		anchor_id: int,
		world_position: Vector2,
		radius: float,
		affected_count: int,
		source_id: StringName
	) -> void:
		events.append({
			"anchor": anchor_id,
			"position": world_position,
			"radius": radius,
			"affected": affected_count,
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
		StringName("anchor_specialization_" + TAIL)
	).effect))
	assert(combat.apply_upgrade_effect(catalog.get_definition(
		StringName("anchor_" + TAIL + "_attach_explosion")
	).effect))

	var orb_id: int = anchors.get_installation_orb_id()
	assert(orb_id >= 0)
	var ground_target: BoardingEnemy = spawn.spawn_debug_archetype(&"basic", 1)
	ground_target.controller.set_physics_process(false)
	ground_target.set_physics_process(false)
	ground_target.global_position = orbs.get_anchor_ground_point(
		orb_id,
		ANCHOR_ID,
		anchors.balance.ground_offsets
	)

	anchors.toggle_anchor(ANCHOR_ID)
	assert(await _wait_until(func() -> bool: return events.size() == 1, 180))
	assert(anchors.is_path_available(ANCHOR_ID))
	assert(events[0]["source"] == StringName("anchor_" + TAIL + "_attach"))
	assert(int(events[0]["affected"]) == 1)
	assert(is_equal_approx(float(events[0]["radius"]), combat.balance.trap_attach_radius))
	assert(not _is_enemy_alive(ground_target))
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
		anchors.get_platform_attachment_world(ANCHOR_ID).x - platform.global_position.x,
		&"basic"
	)
	boarded_target.controller.set_physics_process(false)
	boarded_target.set_physics_process(false)
	anchors.request_remove_all()
	assert(await _wait_until(func() -> bool: return events.size() == 2, 60))
	assert(events[1]["source"] == StringName("anchor_" + TAIL + "_remove"))
	assert(int(events[1]["affected"]) == 1)
	assert(not _is_enemy_alive(boarded_target))
	assert(reward_count == 2)
	assert(visual.get_active_trap_burst_count() >= 1)
	assert(is_equal_approx(
		visual.get_latest_trap_burst_radius(),
		combat.balance.trap_remove_radius
	))
	assert(await _wait_until(
		func() -> bool: return not anchors.is_path_available(ANCHOR_ID),
		180
	))

	combat.reset_upgrade_runtime()
	var plain_target: BoardingEnemy = spawn.spawn_debug_on_platform(
		anchors.get_platform_attachment_world(ANCHOR_ID).x - platform.global_position.x,
		&"basic"
	)
	plain_target.controller.set_physics_process(false)
	plain_target.set_physics_process(false)
	anchors._on_anchor_detaching(ANCHOR_ID)
	assert(events.size() == 2)
	assert(_is_enemy_alive(plain_target))

	print("Combat anchor trap burst scenarios passed")
	quit()


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame: int in range(maximum_frames):
		if predicate.call():
			return true
		await physics_frame
	return bool(predicate.call())


func _is_enemy_alive(enemy: BoardingEnemy) -> bool:
	return is_instance_valid(enemy) and enemy.health.is_alive()


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
