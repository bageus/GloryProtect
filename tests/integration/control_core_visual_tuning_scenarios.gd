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
	_disable_spawners(game)

	var catalog: UpgradeCatalog = game.get_node("UpgradeSystem").catalog
	var coordinator: AnchorlessAutoPrerequisiteCoordinator = game.get_node(
		"UpgradeSystem"
	) as AnchorlessAutoPrerequisiteCoordinator
	var anchorless: AnchorlessControlSystemAutoGate = game.get_node(
		"World/AnchorlessControlSystem"
	) as AnchorlessControlSystemAutoGate
	var overlay: PlatformUpgradeAssetOverlayFinalTuning = game.get_node(
		"World/Platform/PlatformUpgradeAssetOverlay"
	) as PlatformUpgradeAssetOverlayFinalTuning
	var pulse: ShieldCorePulseVisualRadiusFixed = game.get_node(
		"World/ShieldCorePulseVisual"
	) as ShieldCorePulseVisualRadiusFixed
	var minimap: StrategicMinimapRechargeCoreScaled = game.get_node(
		"CanvasLayer/StrategicMinimap"
	) as StrategicMinimapRechargeCoreScaled
	var ground_visual: GroundOrbVisualControllerRechargeNormal = game.get_node(
		"World/GroundOrbVisualController"
	) as GroundOrbVisualControllerRechargeNormal
	var platform_visual: PlatformVisualControllerCoreNormalFixed = game.get_node(
		"World/Platform/PlatformVisualController"
	) as PlatformVisualControllerCoreNormalFixed
	var shield_core: ShieldCoreSystem = game.get_node("World/ShieldCoreSystem")
	var platform: PlatformController = game.get_node("World/Platform")

	assert(catalog != null)
	assert(coordinator != null)
	assert(anchorless != null)
	assert(overlay != null)
	assert(pulse != null)
	assert(minimap != null)
	assert(ground_visual != null)
	assert(platform_visual != null)
	assert(shield_core != null)

	assert(coordinator.get_automatic_steering_prerequisites_for_tests() == [
		&"anchorless_steering_force_basic",
		&"anchorless_wind_reduction_basic",
		&"anchorless_release_drag_basic",
	])
	var auto_effect: UpgradeEffectDefinition = catalog.get_definition(
		&"anchorless_auto_steering"
	).effect
	assert(not anchorless.can_apply_upgrade_effect(auto_effect))
	assert(not overlay.is_automatic_steering_bundle_ready_for_tests())

	for card_id: StringName in [
		&"anchorless_steering_force_basic",
		&"anchorless_wind_reduction_basic",
		&"anchorless_release_drag_basic",
	]:
		assert(anchorless.apply_upgrade_effect(catalog.get_definition(card_id).effect))
	assert(anchorless.is_auto_steering_prerequisite_ready_for_tests())
	assert(anchorless.can_apply_upgrade_effect(auto_effect))
	assert(overlay.is_automatic_steering_bundle_ready_for_tests())
	var visible_ids: PackedStringArray = overlay.get_visible_asset_ids_for_tests()
	assert(visible_ids.has("control"))
	assert(visible_ids.has("stability"))
	assert(visible_ids.has("wind_compensator"))

	assert(is_equal_approx(overlay.get_stability_size_multiplier_for_tests(), 1.3))
	assert(is_equal_approx(overlay.get_stability_overlay_offset_y_for_tests(), 2.0))
	assert(is_equal_approx(overlay.get_control_active_extra_lift_for_tests(), 2.0))
	assert(is_equal_approx(overlay.get_speed_flame_edge_inset_for_tests(), 8.0))
	var stability_size: Vector2 = overlay.get_stability_base_draw_size_for_tests()
	var stability_overlay_size: Vector2 = overlay.get_stability_overlay_draw_size_for_tests()
	assert(stability_size.x > 44.0 or stability_size.y > 36.0)
	assert(stability_overlay_size.x > 0.0 and stability_overlay_size.y > 0.0)

	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		AnchorlessControlUpgradeRuntime.SPEED
	).effect))
	assert(anchorless.apply_upgrade_effect(catalog.get_definition(
		AnchorlessControlUpgradeRuntime.SPEED_FRONT_SWEEP
	).effect))
	assert(overlay.is_front_sweep_visual_visible_for_tests())
	assert(overlay.get_visible_asset_ids_for_tests().has("ramming_edge"))
	var arc_centers: Array[Vector2] = overlay.get_front_sweep_arc_centers_for_tests()
	assert(arc_centers.size() == 2)
	assert(arc_centers[0].x < -platform.get_platform_width() * 0.5)
	assert(arc_centers[1].x > platform.get_platform_width() * 0.5)

	assert(is_equal_approx(pulse.get_anchorless_core_pulse_radius_for_tests(), 320.0))
	assert(is_equal_approx(
		pulse.get_ground_radius_wave_half_width_for_tests(1.0),
		320.0
	))
	assert(is_equal_approx(
		pulse.get_platform_radius_wave_radius_for_tests(1.0),
		320.0
	))

	assert(ground_visual.get_ground_core_atlas_path_for_tests() == (
		"res://visual/tiles/atlas_ground_core_normal.png"
	))
	assert(platform_visual.get_platform_core_atlas_path_for_tests() == (
		"res://visual/tiles/atlas_platform_core_normal.png"
	))
	assert(is_equal_approx(minimap.get_current_core_scale_for_tests(), 1.0))
	assert(shield_core.apply_upgrade_effect(catalog.get_definition(
		&"shield_recharge_basic"
	).effect))
	await process_frame
	assert(is_equal_approx(minimap.get_current_core_scale_for_tests(), 2.0))
	assert(ground_visual.get_ground_core_atlas_path_for_tests() == (
		"res://visual/tiles/atlas_ground_core_normal.png"
	))
	assert(platform_visual.get_platform_core_atlas_path_for_tests() == (
		"res://visual/tiles/atlas_platform_core_normal.png"
	))
	assert(shield_core.apply_upgrade_effect(catalog.get_definition(
		&"shield_recharge_advanced"
	).effect))
	await process_frame
	assert(is_equal_approx(minimap.get_current_core_scale_for_tests(), 2.0))
	assert(ground_visual.get_ground_core_atlas_path_for_tests() == (
		"res://visual/tiles/atlas_ground_core_normal.png"
	))
	assert(platform_visual.get_platform_core_atlas_path_for_tests() == (
		"res://visual/tiles/atlas_platform_core_normal.png"
	))

	print("Control and core visual tuning scenarios passed")
	quit()


func _disable_spawners(game: Node) -> void:
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
		var node: Node = game.get_node(path)
		node.set_process(false)
		node.set_physics_process(false)
