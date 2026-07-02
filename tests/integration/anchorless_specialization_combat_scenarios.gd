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
	var anchors: AnchorSystem = game.get_node("World/AnchorSystem")
	var spawn: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	var flying_spawn: FlyingEnemySpawnDirector = game.get_node(
		"World/FlyingEnemySpawnDirector"
	)
	var orbs: GroundOrbRegistry = game.get_node("World/GroundOrbRegistry")
	var pulse_visual: ShieldCorePulseVisual = game.get_node(
		"World/ShieldCorePulseVisual"
	)
	var upgrade_system: UpgradeSystem = game.get_node("UpgradeSystem")
	var catalog: UpgradeCatalog = upgrade_system.catalog
	anchorless.set_physics_process(false)
	contact.set_physics_process(false)
	anchors.set_physics_process(false)

	await _test_anchor_discharge(
		anchorless,
		platform,
		contact,
		anchors,
		spawn,
		orbs,
		catalog
	)
	await _test_core_pulses(
		anchorless,
		platform,
		contact,
		spawn,
		flying_spawn,
		orbs,
		pulse_visual,
		catalog
	)

	print("Anchorless specialization combat scenarios passed")
	quit()


func _test_anchor_discharge(
	anchorless: AnchorlessControlSystem,
	platform: PlatformController,
	contact: OrbContactSystem,
	anchors: AnchorSystem,
	spawn: BoardingSpawnDirector,
	orbs: GroundOrbRegistry,
	catalog: UpgradeCatalog
) -> void:
	anchorless.reset_upgrade_runtime()
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_specialization_powerful"
	).effect))
	platform.position.x = orbs.get_world_x(2)
	anchors.toggle_anchor(0)
	anchors._physics_process(anchors.balance.install_duration + 0.1)
	var snapshot: AnchorPathSnapshot = anchors.get_path_snapshot(0)
	assert(snapshot != null)
	assert(anchorless.get_last_anchor_point(snapshot.side).is_equal_approx(
		snapshot.ground_point
	))
	var enemy: BoardingEnemy = spawn.spawn_debug_archetype(&"brute", 1)
	enemy.controller.set_physics_process(false)
	enemy.global_position = snapshot.ground_point
	contact.active_orb_id = -1
	contact._set_active_orb(2)
	assert(enemy.health.current_health == enemy.health.max_health - 1)
	anchors.request_remove_all()
	assert(not anchors.is_path_available(0))
	enemy.kill(&"test_cleanup")
	await process_frame


func _test_core_pulses(
	anchorless: AnchorlessControlSystem,
	platform: PlatformController,
	contact: OrbContactSystem,
	spawn: BoardingSpawnDirector,
	flying_spawn: FlyingEnemySpawnDirector,
	orbs: GroundOrbRegistry,
	pulse_visual: ShieldCorePulseVisual,
	catalog: UpgradeCatalog
) -> void:
	anchorless.reset_upgrade_runtime()
	assert(pulse_visual.is_anchorless_connected_for_tests())
	assert(is_zero_approx(pulse_visual.get_ground_lift_offset_for_tests(0.0)))
	assert(pulse_visual.get_ground_lift_offset_for_tests(0.5) < -1.0)
	var pulse_events: Array[Dictionary] = []
	anchorless.core_pulse_requested.connect(func(
		section_id: int,
		source: int,
		damaged_count: int
	) -> void:
		pulse_events.append({
			"section": section_id,
			"source": source,
			"damaged": damaged_count,
		})
	)
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

	var ground_near: BoardingEnemy = spawn.spawn_debug_archetype(&"brute", 1)
	ground_near.controller.set_physics_process(false)
	ground_near.global_position = orbs.get_orb_world_position(2)

	var ground_far: BoardingEnemy = spawn.spawn_debug_archetype(&"brute", -1)
	ground_far.controller.set_physics_process(false)
	ground_far.global_position = orbs.get_orb_world_position(2) + Vector2(1000.0, 0.0)

	var boarded_center: BoardingEnemy = spawn.spawn_debug_on_platform(0.0, &"brute")
	boarded_center.controller.set_physics_process(false)

	var boarded_edge: BoardingEnemy = spawn.spawn_debug_on_platform(
		platform.get_platform_width() * 0.45,
		&"brute"
	)
	boarded_edge.controller.set_physics_process(false)

	var flying_on_connect: BoardingEnemy = flying_spawn.spawn_now(1)
	flying_on_connect.behavior.set_physics_process(false)
	flying_on_connect.global_position = platform.global_position + Vector2(1000.0, -40.0)

	var climbing: BoardingEnemy = spawn.spawn_debug_archetype(&"brute", 1)
	climbing.controller.set_physics_process(false)
	climbing.controller.state = BoardingEnemyController.State.CLIMBING
	climbing.global_position = platform.global_position + Vector2(0.0, 40.0)

	var ground_started: int = pulse_visual.get_started_pulse_count(
		ShieldCoreSystem.SurgePulseSource.GROUND_CORE
	)
	var platform_started: int = pulse_visual.get_started_pulse_count(
		ShieldCoreSystem.SurgePulseSource.PLATFORM_CORE
	)
	contact.active_orb_id = -1
	contact._set_active_orb(2)
	_assert_core_pulse_event(
		pulse_events[0],
		ShieldCoreSystem.SurgePulseSource.GROUND_CORE,
		2
	)
	_assert_core_pulse_event(
		pulse_events[1],
		ShieldCoreSystem.SurgePulseSource.PLATFORM_CORE,
		3
	)
	assert(pulse_visual.get_started_pulse_count(
		ShieldCoreSystem.SurgePulseSource.GROUND_CORE
	) == ground_started + 1)
	assert(pulse_visual.get_started_pulse_count(
		ShieldCoreSystem.SurgePulseSource.PLATFORM_CORE
	) == platform_started + 1)
	assert(ground_near.health.current_health == ground_near.health.max_health - 2)
	assert(ground_far.health.current_health == ground_far.health.max_health - 2)
	assert(boarded_center.health.current_health == boarded_center.health.max_health - 2)
	assert(boarded_edge.health.current_health == boarded_edge.health.max_health - 2)
	assert(not flying_on_connect.health.is_alive())
	assert(climbing.health.current_health == climbing.health.max_health)

	var flying_on_disconnect: BoardingEnemy = flying_spawn.spawn_now(-1)
	flying_on_disconnect.behavior.set_physics_process(false)
	flying_on_disconnect.global_position = (
		platform.global_position + Vector2(-1000.0, -40.0)
	)
	contact._set_active_orb(-1)
	_assert_core_pulse_event(
		pulse_events[2],
		ShieldCoreSystem.SurgePulseSource.GROUND_CORE,
		2
	)
	_assert_core_pulse_event(
		pulse_events[3],
		ShieldCoreSystem.SurgePulseSource.PLATFORM_CORE,
		3
	)
	assert(not ground_near.health.is_alive())
	assert(not ground_far.health.is_alive())
	assert(not boarded_center.health.is_alive())
	assert(not boarded_edge.health.is_alive())
	assert(not flying_on_disconnect.health.is_alive())
	assert(climbing.health.current_health == climbing.health.max_health)

	ground_near.kill(&"test_cleanup")
	ground_far.kill(&"test_cleanup")
	boarded_center.kill(&"test_cleanup")
	boarded_edge.kill(&"test_cleanup")
	flying_on_connect.kill(&"test_cleanup")
	flying_on_disconnect.kill(&"test_cleanup")
	climbing.kill(&"test_cleanup")
	await process_frame


func _assert_core_pulse_event(
	event: Dictionary,
	expected_source: int,
	expected_damaged: int
) -> void:
	assert(int(event["section"]) == 2)
	assert(int(event["source"]) == expected_source)
	assert(int(event["damaged"]) == expected_damaged)


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
