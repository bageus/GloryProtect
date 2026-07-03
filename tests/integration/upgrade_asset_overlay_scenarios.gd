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
	var platform: PlatformController = game.get_node("World/Platform")
	var anchor_visual: CombatAnchorVisualController = anchors.get_node(
		"AnchorVisualController"
	) as CombatAnchorVisualController
	assert(catalog != null)
	assert(shield_core != null)
	assert(anchorless != null)
	assert(combat != null)
	assert(overlay != null)
	assert(anchor_visual != null)

	assert(overlay.get_visible_asset_ids_for_tests().is_empty())
	assert(overlay.get_speed_engine_count_for_tests() == 0)
	assert(not anchor_visual.is_reinforced_chain_visual_active())

	assert(shield_core.apply_upgrade_effect(
		catalog.get_definition(ShieldCoreUpgradeRuntime.DISTRIBUTED).effect
	))
	await process_frame
	assert(overlay.get_core_overlay_asset_for_tests() == &"distributed_border")
	shield_core.reset_upgrade_runtime()
	assert(shield_core.apply_upgrade_effect(
		catalog.get_definition(ShieldCoreUpgradeRuntime.FOCUSED).effect
	))
	await process_frame
	assert(overlay.get_core_overlay_asset_for_tests() == &"focused_border")
	shield_core.reset_upgrade_runtime()
	assert(shield_core.apply_upgrade_effect(
		catalog.get_definition(ShieldCoreUpgradeRuntime.SURGE).effect
	))
	await process_frame
	assert(overlay.get_core_overlay_asset_for_tests() == &"surge_splash")
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
	anchorless.reset_upgrade_runtime()
	assert(anchorless.apply_upgrade_effect(
		catalog.get_definition(AnchorlessControlUpgradeRuntime.PRECISE).effect
	))
	overlay.debug_trigger_direction_change_for_tests(1)
	await process_frame
	assert(overlay.is_stability_asset_visible())
	assert(overlay.is_stability_pulse_active_for_tests())
	anchorless.reset_upgrade_runtime()
	await process_frame
	assert(not overlay.is_stability_asset_visible())

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
