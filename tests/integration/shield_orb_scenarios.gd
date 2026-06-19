extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame

	var game_flow := game.get_node("GameFlowController") as GameFlowController
	var shield := game.get_node("ShieldSystem") as ShieldSystem
	var platform := game.get_node("World/Platform") as PlatformController
	var registry := game.get_node("World/GroundOrbRegistry") as GroundOrbRegistry
	var contact := game.get_node("World/OrbContactSystem") as OrbContactSystem
	var recharge := (
		game.get_node("World/ShieldRechargeController")
		as ShieldRechargeController
	)
	var wind := game.get_node("WindSystem") as WindSystem

	wind.balance.level_forces = PackedFloat32Array([0.0, 0.0, 0.0])
	wind.balance.fluctuation_force = 0.0
	wind.set_debug_state(1, 1)
	platform.horizontal_velocity = 0.0

	assert(shield.get_section_count() == 5)
	assert(registry.get_orb_count() == 5)
	for section_id in range(5):
		assert(is_equal_approx(shield.get_health_percent(section_id), 100.0))

	platform.position.x = registry.get_world_x(2)
	contact._physics_process(0.0)
	assert(contact.get_active_orb_id() == 2)
	assert(contact.get_active_section_id() == 2)

	shield.apply_damage(2, 20.0)
	var section_two_before := shield.get_health(2)
	recharge._physics_process(1.0)
	assert(
		is_equal_approx(
			shield.get_health(2),
			section_two_before + shield.balance.recharge_per_second
		)
	)

	platform.position.x = registry.get_world_x(3)
	contact._physics_process(0.0)
	assert(contact.get_active_orb_id() == 3)
	shield.apply_damage(3, 20.0)
	var section_two_fixed := shield.get_health(2)
	var section_three_before := shield.get_health(3)
	recharge._physics_process(1.0)
	assert(is_equal_approx(shield.get_health(2), section_two_fixed))
	assert(
		is_equal_approx(
			shield.get_health(3),
			section_three_before + shield.balance.recharge_per_second
		)
	)

	platform.position.x = 500.0
	contact._physics_process(0.0)
	assert(not contact.is_contact_active())
	var no_contact_health := shield.get_health(3)
	recharge._physics_process(1.0)
	assert(is_equal_approx(shield.get_health(3), no_contact_health))

	shield.set_health(0, 51.0)
	assert(not shield.needs_direction_indicator(0))
	shield.set_health(0, 50.0)
	assert(shield.needs_direction_indicator(0))

	shield.set_health(4, 0.0)
	assert(game_flow.state == GameFlowController.RunState.GAME_OVER)
	assert(game_flow.game_over_reason == &"shield_section_destroyed")

	print("Shield and orb scenarios passed")
	quit()
