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
	_stabilize_world(game)

	var upgrade_system: UpgradeSystem = game.get_node("UpgradeSystem")
	var core: ShieldCoreSystem = game.get_node("World/ShieldCoreSystem")
	var shield: ShieldCoreShieldSystem = game.get_node("ShieldSystem")
	var recharge: ShieldCoreRechargeController = game.get_node(
		"World/ShieldRechargeController"
	)
	var registry: ShieldCoreGroundOrbRegistry = game.get_node(
		"World/GroundOrbRegistry"
	)
	var contact: OrbContactSystem = game.get_node("World/OrbContactSystem")
	var waves: ShieldCoreStrategicWaveSystem = game.get_node(
		"World/StrategicWaveSystem"
	)
	contact.set_physics_process(false)
	recharge.set_physics_process(false)
	waves.set_physics_process(false)

	_apply(upgrade_system, &"shield_capacity_basic")
	_apply(upgrade_system, &"shield_capacity_advanced")
	_apply(upgrade_system, &"shield_recharge_basic")
	_apply(upgrade_system, &"shield_recharge_advanced")
	_apply(upgrade_system, &"shield_contact_basic")
	_apply(upgrade_system, &"shield_contact_advanced")
	assert(is_equal_approx(shield.get_capacity_multiplier(), 1.2))
	assert(is_equal_approx(recharge.get_speed_multiplier(), 1.2))
	assert(is_equal_approx(registry.get_contact_width_multiplier(), 1.2))
	assert(is_equal_approx(registry.get_contact_half_width(), 86.4))

	_apply(upgrade_system, ShieldCoreUpgradeRuntime.DISTRIBUTED)
	assert(is_equal_approx(recharge.get_distribution_ratio(), 0.15))
	shield.set_health(2, 50.0)
	shield.set_health(0, 40.0)
	contact.call("_set_active_orb", 2)
	recharge.call("_physics_process", 1.0)
	assert(is_equal_approx(shield.get_health(2), 58.16))
	assert(is_equal_approx(shield.get_health(0), 41.44))

	shield.set_health(1, 5.0)
	shield.apply_damage(1, 10.0)
	assert(shield.has_emergency_reserve_been_used())
	assert(is_equal_approx(shield.get_display_health_percent(1), 1.0))
	assert(shield.is_section_held(1))

	core.reset_upgrade_runtime()
	assert(is_zero_approx(core.upgrades.capacity_bonus_ratio))
	assert(is_equal_approx(shield.get_capacity_multiplier(), 1.0))
	assert(is_equal_approx(recharge.get_speed_multiplier(), 1.0))
	assert(is_equal_approx(registry.get_contact_width_multiplier(), 1.0))
	assert(not shield.has_emergency_reserve_been_used())

	core.set_random_seed(28)
	assert(core.apply_upgrade_effect(
		upgrade_system.catalog.get_definition(
			ShieldCoreUpgradeRuntime.FOCUSED
		).effect
	))
	assert(is_equal_approx(recharge.get_speed_multiplier(), 1.15))
	waves.reset_for_run()
	assert(waves.add_group(2, 10, 100.0, 0.0) >= 0)
	contact.call("_set_active_orb", -1)
	contact.call("_set_active_orb", 2)
	assert(waves.get_total_enemy_count() == 10)
	assert(waves.get_enemy_count_for_section(2) == 7)

	core.reset_upgrade_runtime()
	waves.reset_for_run()
	contact.call("_set_active_orb", -1)
	core.set_random_seed(9)
	assert(core.apply_upgrade_effect(
		upgrade_system.catalog.get_definition(
			ShieldCoreUpgradeRuntime.SURGE
		).effect
	))
	assert(waves.add_group(2, 5, 100.0, 0.0) >= 0)
	var before_surge := waves.get_total_enemy_count()
	contact.call("_set_active_orb", 2)
	var destroyed_on_connect := before_surge - waves.get_total_enemy_count()
	assert(destroyed_on_connect >= 1 and destroyed_on_connect <= 2)

	shield.set_health(0, 50.0)
	shield.set_health(1, 100.0)
	shield.set_health(3, 100.0)
	shield.set_health(4, 100.0)
	shield.set_health(2, 99.0)
	shield.restore(2, 1.0)
	assert(is_equal_approx(shield.get_health(0), 65.0))

	print("Shield core upgrade scenarios passed")
	quit()


func _apply(system: UpgradeSystem, card_id: StringName) -> void:
	var definition: UpgradeDefinition = system.catalog.get_definition(card_id)
	assert(definition != null)
	assert(system._effect_applier.can_apply(definition))
	assert(system._effect_applier.apply_effect(definition))


func _stabilize_world(game: Node) -> void:
	var paths: Array[NodePath] = [
		NodePath("World/BoardingSpawnDirector"),
		NodePath("World/FlyingEnemySpawnDirector"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
	]
	for path: NodePath in paths:
		if not game.has_node(path):
			continue
		var system: Node = game.get_node(path)
		system.set_process(false)
		system.set_physics_process(false)
