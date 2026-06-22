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
	var wind: WindSystem = game.get_node("WindSystem")
	var steering: SteeringInputProvider = game.get_node("SteeringInputProvider")
	var contact: OrbContactSystem = game.get_node("World/OrbContactSystem")
	var orbs: GroundOrbRegistry = game.get_node("World/GroundOrbRegistry")
	var shield: ShieldSystem = game.get_node("ShieldSystem")
	var upgrade_system: UpgradeSystem = game.get_node("UpgradeSystem")
	var catalog: UpgradeCatalog = upgrade_system.catalog
	platform.set_physics_process(false)
	wind.set_physics_process(false)
	anchorless.set_physics_process(false)
	contact.set_physics_process(false)

	_test_base_motion_and_wind(anchorless, platform, wind, steering, catalog)
	_test_precise_contact(anchorless, platform, contact, orbs, catalog)
	_test_speed_contact(anchorless, platform, wind, contact, shield, catalog)
	_test_run_reset(flow, anchorless, platform, wind)

	Input.action_release("ui_left")
	Input.action_release("ui_right")
	print("Anchorless movement and contact scenarios passed")
	quit()


func _test_base_motion_and_wind(
	anchorless: AnchorlessControlSystem,
	platform: PlatformController,
	wind: WindSystem,
	steering: SteeringInputProvider,
	catalog: UpgradeCatalog
) -> void:
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_steering_force_basic"
	).effect))
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_steering_force_advanced"
	).effect))
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_wind_reduction_basic"
	).effect))
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_wind_reduction_advanced"
	).effect))
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_release_drag_basic"
	).effect))
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_release_drag_advanced"
	).effect))
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_auto_steering"
	).effect))
	assert(is_equal_approx(
		platform.get_effective_steering_force(),
		platform.balance.steering_force * 1.2
	))
	assert(is_equal_approx(
		platform.get_effective_linear_drag(false),
		platform.balance.linear_drag * 1.4
	))
	assert(is_equal_approx(
		platform.get_effective_linear_drag(true),
		platform.balance.linear_drag
	))
	assert(is_equal_approx(wind.get_influence_multiplier(), 0.8))
	wind.elapsed_time = 0.0
	wind.set_debug_state(1, 1)
	assert(is_zero_approx(wind.get_current_force()))
	wind.set_debug_state(1, 2)
	assert(wind.get_current_force() > 0.0)

	wind.set_debug_state(1, 1)
	platform.horizontal_velocity = 0.0
	platform.position.x = 0.0
	steering.set_driver_available(false)
	Input.action_press("ui_right")
	platform._physics_process(0.1)
	assert(is_zero_approx(platform.horizontal_velocity))
	steering.set_driver_available(true)
	platform._physics_process(0.1)
	assert(platform.horizontal_velocity > 0.0)
	Input.action_release("ui_right")

	platform.position.x = platform.balance.world_max_x
	platform.horizontal_velocity = 200.0
	platform._physics_process(0.5)
	assert(is_equal_approx(platform.position.x, platform.balance.world_max_x))
	assert(is_zero_approx(platform.horizontal_velocity))


func _test_precise_contact(
	anchorless: AnchorlessControlSystem,
	platform: PlatformController,
	contact: OrbContactSystem,
	orbs: GroundOrbRegistry,
	catalog: UpgradeCatalog
) -> void:
	anchorless.reset_upgrade_runtime()
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_specialization_precise"
	).effect))
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_precise_recharge"
	).effect))
	assert(is_equal_approx(
		platform.get_effective_linear_drag(false),
		platform.balance.linear_drag * 1.25
	))
	contact.active_orb_id = 2
	platform.position.x = orbs.get_world_x(2)
	assert(is_equal_approx(anchorless.get_shield_recharge_multiplier(2), 1.25))
	platform.position.x += orbs.get_contact_half_width() * 0.8
	assert(is_equal_approx(anchorless.get_shield_recharge_multiplier(2), 1.0))


func _test_speed_contact(
	anchorless: AnchorlessControlSystem,
	platform: PlatformController,
	wind: WindSystem,
	contact: OrbContactSystem,
	shield: ShieldSystem,
	catalog: UpgradeCatalog
) -> void:
	anchorless.reset_upgrade_runtime()
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_specialization_speed"
	).effect))
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_speed_long_flight_restore"
	).effect))
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_auto_steering"
	).effect))
	assert(is_equal_approx(
		platform.get_effective_steering_force(),
		platform.balance.steering_force * 1.15
	))
	assert(is_equal_approx(
		platform.get_effective_max_horizontal_speed(),
		platform.balance.max_horizontal_speed * 1.15
	))
	contact.active_orb_id = -1
	platform.horizontal_velocity = anchorless.balance.long_flight_minimum_speed + 1.0
	anchorless._physics_process(anchorless.balance.long_flight_required_seconds)
	shield.set_health(2, 50.0)
	platform.position.x = 0.0
	contact._set_active_orb(2)
	assert(is_equal_approx(shield.get_health(2), 60.0))
	wind.elapsed_time = 0.0
	wind.set_debug_state(1, 1)
	platform._physics_process(0.1)
	assert(is_zero_approx(platform.horizontal_velocity))


func _test_run_reset(
	flow: GameFlowController,
	anchorless: AnchorlessControlSystem,
	platform: PlatformController,
	wind: WindSystem
) -> void:
	flow.start_run()
	assert(anchorless.upgrades.specialization_id == &"")
	assert(is_equal_approx(
		platform.get_effective_steering_force(),
		platform.balance.steering_force
	))
	assert(is_equal_approx(
		platform.get_effective_max_horizontal_speed(),
		platform.balance.max_horizontal_speed
	))
	assert(is_equal_approx(wind.get_influence_multiplier(), 1.0))
	assert(not wind.is_strength_one_ignored())


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
