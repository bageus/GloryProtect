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
	var shield_core: ShieldCoreSystem = game.get_node("World/ShieldCoreSystem")
	var anchorless: AnchorlessControlSystem = game.get_node("World/AnchorlessControlSystem")
	var combat: CombatAnchorSystem = game.get_node("World/CombatAnchorSystem")
	var anchors: CombatAnchorHostSystem = game.get_node("World/AnchorSystem")
	var overlay: PlatformUpgradeAssetOverlay = game.get_node(
		"World/Platform/PlatformUpgradeAssetOverlay"
	)
	var stability_overlay: PlatformUpgradeAssetOverlayStabilityFixed = (
		overlay as PlatformUpgradeAssetOverlayStabilityFixed
	)
	var platform: PlatformController = game.get_node("World/Platform")
	var contact: OrbContactSystem = game.get_node("World/OrbContactSystem")
	var platform_visual: PlatformVisualController = game.get_node(
		"World/Platform/PlatformVisualController"
	)
	var anchor_visual: CombatAnchorVisualController = anchors.get_node(
		"AnchorVisualController"
	) as CombatAnchorVisualController
	assert(catalog != null)
	assert(shield_core != null)
	assert(anchorless != null)
	assert(combat != null)
	assert(overlay != null)
	assert(stability_overlay != null)
	assert(platform_visual != null)
	assert(contact != null)
	assert(anchor_visual != null)

	assert(overlay.get_visible_asset_ids_for_tests().is_empty())
	assert(overlay.get_speed_engine_count_for_tests() == 0)
	assert(not anchor_visual.is_reinforced_chain_visual_active())
	assert(anchor_visual.get_clamp_asset_id_for_tests() == &"base")
	assert(anchor_visual.get_anchor_asset_id_for_tests() == &"base")
	assert(not anchor_visual.is_turbo_anchor_grounded_for_tests())
	assert(overlay.get_core_overlay_center_for_tests().is_equal_approx(
		overlay.get_platform_core_center_for_tests()
	))
	assert(overlay.get_platform_core_center_for_tests().y > 0.0)

	assert(shield_core.apply_upgrade_effect(
		catalog.get_definition(ShieldCoreUpgradeRuntime.DISTRIBUTED).effect
	))
	await process_frame
	assert(overlay.get_core_overlay_asset_for_tests() == &"distributed_border")
	assert(overlay.get_distributed_core_overlay_scale_for_tests() > 1.0)
	assert(is_equal_approx(
		overlay.get_distributed_core_overlay_scale_for_tests(),
		1.11
	))
	assert(overlay.get_core_overlay_draw_size_for_tests().is_equal_approx(
		overlay.core_overlay_size * overlay.get_distributed_core_overlay_scale_for_tests()
	))
	assert(overlay.get_core_overlay_center_for_tests().is_equal_approx(
		overlay.get_platform_core_center_for_tests()
	))
	shield_core.reset_upgrade_runtime()
	assert(shield_core.apply_upgrade_effect(
		catalog.get_definition(ShieldCoreUpgradeRuntime.FOCUSED).effect
	))
	await process_frame
	assert(overlay.get_core_overlay_asset_for_tests() == &"focused_border")
	assert(overlay.get_focused_core_overlay_scale_for_tests() < 1.0)
	assert(overlay.get_core_overlay_draw_size_for_tests().is_equal_approx(
		overlay.core_overlay_size * overlay.get_focused_core_overlay_scale_for_tests()
	))
	shield_core.reset_upgrade_runtime()
	assert(shield_core.apply_upgrade_effect(
		catalog.get_definition(ShieldCoreUpgradeRuntime.SURGE).effect
	))
	await process_frame
	assert(overlay.get_core_overlay_asset_for_tests() == &"surge_splash")
	assert(overlay.get_core_overlay_draw_size_for_tests().is_equal_approx(
		overlay.core_overlay_size
	))
	var original_platform_position: Vector2 = platform.position
	contact.call("_set_active_orb", 0)
	await process_frame
	var initial_surge_direction: Vector2 = overlay.get_core_overlay_beam_direction_for_tests()
	var initial_surge_rotation: float = overlay.get_core_overlay_rotation_for_tests()
	assert(initial_surge_direction.length() > 0.9)
	assert(Vector2.DOWN.rotated(initial_surge_rotation).dot(initial_surge_direction) > 0.99)
	platform.position.x += 120.0
	overlay.call("_process", 0.1)
	var moved_surge_direction: Vector2 = overlay.get_core_overlay_beam_direction_for_tests()
	var moved_surge_rotation: float = overlay.get_core_overlay_rotation_for_tests()
	assert(moved_surge_direction.length() > 0.9)
	assert(absf(wrapf(
		moved_surge_rotation - initial_surge_rotation,
		-PI,
		PI
	)) > 0.001)
	assert(Vector2.DOWN.rotated(moved_surge_rotation).dot(moved_surge_direction) > 0.99)
	platform.position = original_platform_position
	contact.call("_set_active_orb", -1)
	shield_core.reset_upgrade_runtime()
	await process_frame
	assert(overlay.get_core_overlay_asset_for_tests() == &"")

	assert(anchorless.apply_upgrade_effect(
		catalog.get_definition(AnchorlessControlUpgradeRuntime.SPEED).effect
	))
	platform.horizontal_velocity = -40.0
	overlay.call("_process", 0.1)
	assert(overlay.is_speed_asset_visible())
	assert(overlay.get_speed_engine_count_for_tests() == 2)
	assert(overlay.get_active_speed_flame_side_for_tests() == 1)
	anchorless.reset_upgrade_runtime()
	await process_frame
	assert(not overlay.is_speed_asset_visible())

	assert(anchorless.apply_upgrade_effect(
		catalog.get_definition(&"anchorless_steering_force_basic").effect
	))
	await process_frame
	assert(overlay.is_control_mechanism_visible())
	_assert_control_mechanism_layout(stability_overlay, platform)
	anchorless.reset_upgrade_runtime()
	assert(anchorless.apply_upgrade_effect(
		catalog.get_definition(AnchorlessControlUpgradeRuntime.PRECISE).effect
	))
	overlay.debug_trigger_direction_change_for_tests(1)
	await process_frame
	assert(overlay.is_stability_asset_visible())
	assert(overlay.is_stability_pulse_active_for_tests())
	_assert_stability_layout(stability_overlay, platform)
	anchorless.reset_upgrade_runtime()
	await process_frame
	assert(not overlay.is_stability_asset_visible())

	assert(combat.apply_upgrade_effect(
		catalog.get_definition(&"anchor_install_speed_basic").effect
	))
	await process_frame
	assert(anchor_visual.get_clamp_asset_id_for_tests() == &"fastening")
	assert(anchor_visual.get_anchor_asset_id_for_tests() == &"base")
	assert(not anchor_visual.is_turbo_anchor_grounded_for_tests())
	assert(combat.apply_upgrade_effect(
		catalog.get_definition(&"anchor_install_speed_advanced").effect
	))
	await process_frame
	assert(anchor_visual.get_clamp_asset_id_for_tests() == &"turbo_fastening")
	assert(anchor_visual.get_anchor_asset_id_for_tests() == &"magnet_anchor")
	assert(anchor_visual.is_turbo_anchor_grounded_for_tests())
	combat.reset_upgrade_runtime()
	await process_frame
	assert(anchor_visual.get_clamp_asset_id_for_tests() == &"base")
	assert(anchor_visual.get_anchor_asset_id_for_tests() == &"base")
	assert(not anchor_visual.is_turbo_anchor_grounded_for_tests())

	assert(combat.apply_upgrade_effect(
		catalog.get_definition(CombatAnchorUpgradeRuntime.STRONG).effect
	))
	await process_frame
	assert(anchor_visual.is_reinforced_chain_visual_active())
	combat.reset_upgrade_runtime()
	await process_frame
	assert(not anchor_visual.is_reinforced_chain_visual_active())

	print("Upgrade asset overlay scenarios passed")
	quit()


func _assert_control_mechanism_layout(
	overlay: PlatformUpgradeAssetOverlayStabilityFixed,
	platform: PlatformController
) -> void:
	overlay.set("_elapsed", 0.0)
	var base_center: Vector2 = overlay.get_control_base_center_for_tests()
	var active_center: Vector2 = overlay.get_control_active_center_for_tests()
	var base_size: Vector2 = overlay.control_mechanism_size
	var active_size: Vector2 = overlay.control_active_size
	var platform_top: float = -platform.balance.platform_height * 0.5
	var platform_bottom: float = platform.balance.platform_height * 0.5
	var front_edge: float = overlay.get_platform_edge_x_for_tests(1)
	var base_left: float = base_center.x - base_size.x * 0.5
	var base_right: float = base_center.x + base_size.x * 0.5
	assert(base_left < front_edge)
	assert(base_right > front_edge)
	assert(is_equal_approx(
		front_edge - base_left,
		overlay.get_control_front_overlap_for_tests()
	))
	assert(base_center.y > platform_top)
	assert(base_center.y < platform_bottom)
	assert(is_equal_approx(base_center.y, overlay.control_front_vertical_offset))
	assert(active_size.x < base_size.x)
	assert(active_size.y < base_size.y)
	assert(active_center.x > base_right)
	assert(is_equal_approx(
		active_center.y + active_size.y * 0.5,
		base_center.y + base_size.y * 0.5
	))
	overlay.call("_process", 0.1)
	var moved_active_center: Vector2 = overlay.get_control_active_center_for_tests()
	assert(moved_active_center.x > active_center.x)
	assert(is_equal_approx(moved_active_center.y, active_center.y))


func _assert_stability_layout(
	overlay: PlatformUpgradeAssetOverlayStabilityFixed,
	platform: PlatformController
) -> void:
	var centers: Array[Vector2] = overlay.get_stability_base_centers_for_tests()
	var left_center: Vector2 = centers[0]
	var right_center: Vector2 = centers[1]
	var base_size: Vector2 = overlay.get_stability_base_draw_size_for_tests()
	var overlay_size: Vector2 = overlay.get_stability_overlay_draw_size_for_tests()
	var left_overlay_center: Vector2 = overlay.get_stability_overlay_center_for_tests(-1)
	var right_overlay_center: Vector2 = overlay.get_stability_overlay_center_for_tests(1)
	var left_edge: float = overlay.get_platform_edge_x_for_tests(-1)
	var right_edge: float = overlay.get_platform_edge_x_for_tests(1)

	assert(left_edge < 0.0)
	assert(right_edge > 0.0)
	assert(is_equal_approx(left_edge, -platform.get_platform_width() * 0.5))
	assert(is_equal_approx(right_edge, platform.get_platform_width() * 0.5))
	assert(left_center.x < left_edge)
	assert(right_center.x > right_edge)
	assert(is_equal_approx(
		left_center.x + base_size.x * 0.5,
		left_edge + overlay.stability_edge_overlap
	))
	assert(is_equal_approx(
		right_center.x - base_size.x * 0.5,
		right_edge - overlay.stability_edge_overlap
	))
	assert(is_equal_approx(left_center.y, overlay.stability_vertical_offset))
	assert(is_equal_approx(right_center.y, overlay.stability_vertical_offset))
	assert(overlay.is_stability_side_mirrored_for_tests(-1))
	assert(not overlay.is_stability_side_mirrored_for_tests(1))
	assert(is_equal_approx(left_overlay_center.x, left_center.x))
	assert(is_equal_approx(right_overlay_center.x, right_center.x))
	assert(is_equal_approx(
		left_overlay_center.y + overlay_size.y * 0.5,
		left_center.y + base_size.y * 0.5 - overlay.stability_overlay_bottom_padding
	))
	assert(is_equal_approx(
		right_overlay_center.y + overlay_size.y * 0.5,
		right_center.y + base_size.y * 0.5 - overlay.stability_overlay_bottom_padding
	))
	assert(overlay.get_stability_base_scale_for_tests() > 0.0)
	assert(base_size.x > 0.0)
	assert(base_size.y > 0.0)
	assert(overlay_size.x > 0.0)
	assert(overlay_size.y > 0.0)


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
