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
	var recharge: ShieldRechargeController = game.get_node(
		"World/ShieldRechargeController"
	)
	var orbs: GroundOrbRegistry = game.get_node("World/GroundOrbRegistry")
	var shield: ShieldSystem = game.get_node("ShieldSystem")
	var upgrade_system: UpgradeSystem = game.get_node("UpgradeSystem")
	var catalog: UpgradeCatalog = upgrade_system.catalog
	contact.set_physics_process(false)
	recharge.set_physics_process(false)

	anchorless.reset_upgrade_runtime()
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_specialization_precise"
	).effect))
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		&"anchorless_precise_recharge"
	).effect))

	shield.set_health(2, 40.0)
	platform.position.x = orbs.get_world_x(2)
	contact._physics_process(0.0)
	assert(contact.get_active_orb_id() == 2)
	recharge._physics_process(1.0)
	var center_expected: float = (
		40.0 + recharge.balance.recharge_per_second * 1.25
	)
	assert(is_equal_approx(shield.get_health(2), center_expected))

	platform.position.x = (
		orbs.get_world_x(2) + orbs.get_contact_half_width() * 0.8
	)
	contact._physics_process(0.0)
	assert(contact.get_active_orb_id() == 2)
	var before_edge_recharge: float = shield.get_health(2)
	recharge._physics_process(1.0)
	assert(is_equal_approx(
		shield.get_health(2),
		before_edge_recharge + recharge.balance.recharge_per_second
	))
	print("Anchorless precise recharge scenarios passed")
	quit()
