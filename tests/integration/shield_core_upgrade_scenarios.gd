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
	var pulse_visual: ShieldCorePulseVisual = game.get_node(
		"World/ShieldCorePulseVisual"
	)
	var shield: ShieldCoreShieldSystem = game.get_node("ShieldSystem")
	var recharge: ShieldCoreRechargeController = game.get_node(
		"World/ShieldRechargeController"
	)
	var registry: ShieldCoreGroundOrbRegistry = game.get_node(
		"World/GroundOrbRegistry"
	)
	var contact: OrbContactSystem = game.get_node("World/OrbContactSystem")
	var visual: GroundOrbVisualController = game.get_node(
		"World/GroundOrbVisualController"
	)
	var waves: ShieldCoreStrategicWaveSystem = game.get_node(
		"World/StrategicWaveSystem"
	)
	contact.set_physics_process(false)
	recharge.set_physics_process(false)
	waves.set_physics_process(false)

	var base_beam_widths: Vector2 = visual.get_contact_beam_widths_for_tests()
	assert(is_equal_approx(base_beam_widths.x, visual.contact_outer_base_width))
	assert(is_equal_approx(base_beam_widths.y, visual.contact_inner_base_width))
	assert(visual.get_contact_edge_glow_widths_for_tests() == Vector2.ZERO)
	var base_pulse_half_width: float = (
		pulse_visual.get_ground_pulse_half_width_for_tests(1.0)
	)
	assert(is_equal_approx(
		pulse_visual.get_ground_pulse_half_width_for_tests(
			1.0,
			pulse_visual.get_compact_wave_scale_for_tests()
		),
		base_pulse_half_width * 0.9
	))
	assert(is_equal_approx(
		pulse_visual.get_ground_pulse_half_width_for_tests(
			1.0,
			pulse_visual.get_spread_wave_scale_for_tests()
		),
		base_pulse_half_width * 1.1
	))

	_apply(upgrade_system, &"shield_capacity_basic")
	_apply(upgrade_system, &"shield_capacity_advanced")
	_apply(upgrade_system, &"shield_recharge_basic")
	_apply(upgrade_system, &"shield_recharge_advanced")
	_apply(upgrade_system, &"shield_contact_basic")
	var improved_beam_widths: Vector2 = visual.get_contact_beam_widths_for_tests()
	assert(is_equal_approx(
		improved_beam_widths.x,
		base_beam_widths.x * visual.enhanced_contact_visual_width_multiplier
	))
	assert(is_equal_approx(
		improved_beam_widths.y,
		base_beam_widths.y * visual.enhanced_contact_visual_width_multiplier
	))
	var improved_glow_widths: Vector2 = visual.get_contact_edge_glow_widths_for_tests()
	assert(improved_glow_widths.x > improved_beam_widths.x)
	assert(improved_glow_widths.y > improved_beam_widths.x)
	var improved_edge_color: Color = visual.get_contact_edge_color_for_tests()
	assert(improved_edge_color.g > improved_edge_color.b)
	_apply(upgrade_system, &"shield_contact_advanced")
	var mega_beam_widths: Vector2 = visual.get_contact_beam_widths_for_tests()
	assert(is_equal_approx(
		mega_beam_widths.x,
		base_beam_widths.x * visual.mega_contact_visual_width_multiplier
	))
	assert(is_equal_approx(
		mega_beam_widths.y,
		base_beam_widths.y * visual.mega_contact_visual_width_multiplier
	))
	var mega_glow_widths: Vector2 = visual.get_contact_edge_glow_widths_for_tests()
	assert(mega_glow_widths.x > mega_beam_widths.x)
	assert(mega_glow_widths.y > mega_beam_widths.x)
	var mega_edge_color: Color = visual.get_contact_edge_color_for_tests()
	assert(mega_edge_color.b > mega_edge_color.g)
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
	var reset_beam_widths: Vector2 = visual.get_contact_beam_widths_for_tests()
	assert(is_equal_approx(reset_beam_widths.x, base_beam_widths.x))
	assert(is_equal_approx(reset_beam_widths.y, base_beam_widths.y))

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
	assert(pulse_visual.get_active_pulse_count() >= 1)

	waves.reset_for_run()
	contact.call("_set_active_orb", -1)
	assert(waves.add_group(2, 10, 100.0, 0.0) >= 0)
	while waves.get_available_group_slots() > 0:
		assert(waves.add_group(0, 1, 100.0, 0.0) >= 0)
	var full_group_total := waves.get_total_enemy_count()
	contact.call("_set_active_orb", 2)
	assert(waves.get_enemy_count_for_section(2) == 7)
	assert(waves.get_total_enemy_count() == full_group_total)

	core.reset_upgrade_runtime()
	assert(pulse_visual.get_active_pulse_count() == 0)
	waves.reset_for_run()
	contact.call("_set_active_orb", -1)
	core.set_random_seed(9)
	assert(core.apply_upgrade_effect(
		upgrade_system.catalog.get_definition(
			ShieldCoreUpgradeRuntime.SURGE
		).effect
	))
	assert(pulse_visual.get_active_pulse_count() == 0)
	assert(waves.add_group(2, 5, 100.0, 0.0) >= 0)
	var before_surge := waves.get_total_enemy_count()
	contact.call("_set_active_orb", 2)
	var destroyed_on_connect := before_surge - waves.get_total_enemy_count()
	assert(destroyed_on_connect >= 1 and destroyed_on_connect <= 2)
	assert(pulse_visual.get_started_pulse_count(
		ShieldCoreSystem.SurgePulseSource.GROUND_CORE
	) == 1)
	assert(pulse_visual.get_active_pulse_count() == 1)
	var before_disconnect := waves.get_total_enemy_count()
	contact.call("_set_active_orb", -1)
	var destroyed_on_disconnect := before_disconnect - waves.get_total_enemy_count()
	assert(destroyed_on_disconnect >= 1 and destroyed_on_disconnect <= 2)
	assert(pulse_visual.get_started_pulse_count(
		ShieldCoreSystem.SurgePulseSource.PLATFORM_CORE
	) == 1)
	assert(pulse_visual.get_active_pulse_count() == 2)
	contact.call("_set_active_orb", 2)
	assert(pulse_visual.get_started_pulse_count(
		ShieldCoreSystem.SurgePulseSource.GROUND_CORE
	) == 2)
	assert(pulse_visual.get_active_pulse_count() == 3)

	shield.set_health(0, 50.0)
	shield.set_health(1, 100.0)
	shield.set_health(3, 100.0)
	shield.set_health(4, 100.0)
	shield.set_health(2, 99.0)
	shield.restore(2, 1.0)
	assert(is_equal_approx(shield.get_health(0), 65.0))

	var paused_elapsed := pulse_visual.get_oldest_pulse_elapsed_for_tests()
	flow.state = GameFlowController.RunState.MANUAL_PAUSE
	pulse_visual.call("_process", pulse_visual.style.duration + 1.0)
	assert(is_equal_approx(
		pulse_visual.get_oldest_pulse_elapsed_for_tests(),
		paused_elapsed
	))
	flow.state = GameFlowController.RunState.RUNNING
	pulse_visual.call("_process", pulse_visual.style.duration + 1.0)
	assert(pulse_visual.get_active_pulse_count() == 0)

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
