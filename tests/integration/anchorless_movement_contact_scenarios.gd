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
	var anchors: AnchorSystem = game.get_node("World/AnchorSystem")
	var contact: OrbContactSystem = game.get_node("World/OrbContactSystem")
	var orbs: GroundOrbRegistry = game.get_node("World/GroundOrbRegistry")
	var shield: ShieldSystem = game.get_node("ShieldSystem")
	var upgrade_system: UpgradeSystem = game.get_node("UpgradeSystem")
	var catalog: UpgradeCatalog = upgrade_system.catalog
	platform.set_physics_process(false)
	wind.set_physics_process(false)
	anchors.set_physics_process(false)
	anchorless.set_physics_process(false)
	contact.set_physics_process(false)

	_test_base_motion_and_wind(anchorless, platform, wind, steering, catalog)
	_test_anchor_constraint_priority(platform, wind, steering, anchors, orbs)
	_test_precise_contact(anchorless, platform, contact, orbs, catalog)
	_test_pause_preserves_state(flow, anchorless, platform, contact)
	_test_speed_contact(
		anchorless,
		platform,
		wind,
		steering,
		contact,
		shield,
		catalog
	)
	await _test_run_reset(flow, anchorless, platform, wind, contact)

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

	platform.horizontal_velocity = 0.0
	Input.action_press("ui_left")
	Input.action_press("ui_right")
	platform._physics_process(0.1)
	assert(is_zero_approx(platform.steering_axis))
	assert(is_zero_approx(platform.horizontal_velocity))
	Input.action_release("ui_left")
	Input.action_release("ui_right")

	platform.position.x = platform.balance.world_max_x
	platform.horizontal_velocity = 200.0
	platform._physics_process(0.5)
	assert(is_equal_approx(platform.position.x, platform.balance.world_max_x))
	assert(is_zero_approx(platform.horizontal_velocity))


func _test_anchor_constraint_priority(
	platform: PlatformController,
	wind: WindSystem,
	steering: SteeringInputProvider,
	anchors: AnchorSystem,
	orbs: GroundOrbRegistry
) -> void:
	wind.elapsed_time = 0.0
	wind.set_debug_state(1, 1)
	steering.set_driver_available(true)
	platform.position.x = orbs.get_world_x(2)
	platform.horizontal_velocity = 0.0
	anchors.toggle_anchor(0)
	anchors._physics_process(anchors.balance.install_duration + 0.1)
	assert(anchors.is_path_available(0))
	var maximum_x: float = anchors.get_maximum_platform_x()
	assert(maximum_x != INF)
	platform.position.x = maximum_x
	platform.horizontal_velocity = 200.0
	Input.action_press("ui_right")
	platform._physics_process(0.5)
	Input.action_release("ui_right")
	assert(is_equal_approx(platform.position.x, maximum_x))
	assert(is_zero_approx(platform.horizontal_velocity))
	anchors.request_remove_all()
	assert(not anchors.is_path_available(0))


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


func _test_pause_preserves_state(
	flow: GameFlowController,
	anchorless: AnchorlessControlSystem,
	platform: PlatformController,
	contact: OrbContactSystem
) -> void:
	contact.active_orb_id = 2
	platform.horizontal_velocity = 37.0
	var position_before: Vector2 = platform.position
	flow.toggle_manual_pause()
	assert(flow.state == GameFlowController.RunState.MANUAL_PAUSE)
	contact._physics_process(1.0)
	platform._physics_process(1.0)
	anchorless._physics_process(1.0)
	assert(contact.get_active_orb_id() == 2)
	assert(platform.position == position_before)
	assert(is_equal_approx(platform.horizontal_velocity, 37.0))
	flow.toggle_manual_pause()
	assert(flow.state == GameFlowController.RunState.RUNNING)


func _test_speed_contact(
	anchorless: AnchorlessControlSystem,
	platform: PlatformController,
	wind: WindSystem,
	steering: SteeringInputProvider,
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
	anchorless._physics_process(anchorless.balance.long_flight_required_seconds * 0.5)
	assert(anchorless.get_flight_seconds() > 0.0)
	platform.horizontal_velocity = 0.0
	anchorless._physics_process(0.1)
	assert(is_zero_approx(anchorless.get_flight_seconds()))
	platform.horizontal_velocity = anchorless.balance.long_flight_minimum_speed + 1.0
	anchorless._physics_process(anchorless.balance.long_flight_required_seconds)
	shield.set_health(2, 50.0)
	platform.position.x = 0.0
	wind.elapsed_time = 0.0
	wind.set_debug_state(1, 2)
	steering.set_driver_available(true)
	Input.action_press("ui_right")
	contact._set_active_orb(2)
	assert(is_equal_approx(shield.get_health(2), 60.0))
	var health_after_restore: float = shield.get_health(2)
	var contact_x: float = platform.position.x
	platform._physics_process(0.1)
	assert(is_equal_approx(platform.position.x, contact_x))
	assert(is_zero_approx(platform.horizontal_velocity))
	platform._physics_process(0.1)
	assert(platform.horizontal_velocity > 0.0)
	assert(platform.position.x > contact_x)
	Input.action_release("ui_right")
	contact._set_active_orb(-1)
	contact._set_active_orb(2)
	assert(is_equal_approx(shield.get_health(2), health_after_restore))


func _test_run_reset(
	flow: GameFlowController,
	anchorless: AnchorlessControlSystem,
	platform: PlatformController,
	wind: WindSystem,
	contact: OrbContactSystem
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
	await process_frame
	assert(contact.get_active_orb_id() == -1)


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
