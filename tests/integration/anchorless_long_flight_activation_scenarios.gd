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
	var contact: OrbContactSystem = game.get_node("World/OrbContactSystem")
	var orbs: GroundOrbRegistry = game.get_node("World/GroundOrbRegistry")
	var shield: ShieldSystem = game.get_node("ShieldSystem")
	var upgrade_system: UpgradeSystem = game.get_node("UpgradeSystem")
	var catalog: UpgradeCatalog = upgrade_system.catalog
	anchorless.set_physics_process(false)
	contact.set_physics_process(false)

	anchorless.reset_upgrade_runtime()
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_specialization_speed"
	).effect))
	contact.active_orb_id = -1
	platform.horizontal_velocity = anchorless.balance.long_flight_minimum_speed + 1.0
	anchorless._physics_process(anchorless.balance.long_flight_required_seconds)
	assert(is_zero_approx(anchorless.get_flight_seconds()))

	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_speed_long_flight_restore"
	).effect))
	assert(is_zero_approx(anchorless.get_flight_seconds()))
	shield.set_health(2, 50.0)
	platform.position.x = orbs.get_world_x(2)
	contact._physics_process(0.0)
	assert(contact.get_active_orb_id() == 2)
	assert(is_equal_approx(shield.get_health(2), 50.0))

	platform.position.x = (
		orbs.get_world_x(2) + orbs.get_contact_half_width() * 2.0
	)
	contact._physics_process(0.0)
	assert(not contact.is_contact_active())
	platform.horizontal_velocity = anchorless.balance.long_flight_minimum_speed + 1.0
	anchorless._physics_process(anchorless.balance.long_flight_required_seconds)
	assert(is_equal_approx(
		anchorless.get_flight_seconds(),
		anchorless.balance.long_flight_required_seconds
	))

	platform.position.x = orbs.get_world_x(2)
	contact._physics_process(0.0)
	assert(contact.get_active_orb_id() == 2)
	assert(is_equal_approx(shield.get_health(2), 60.0))
	print("Anchorless long-flight activation scenarios passed")
	quit()
