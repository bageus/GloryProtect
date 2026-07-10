extends SceneTree

const BASE_GAME_SCENE := preload("res://scenes/game/game_root.tscn")
const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert_base_scene_has_upgrade_overlay()
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	flow.state = GameFlowController.RunState.RUNNING
	_disable_spawners(game)

	var platform: PlatformController = game.get_node("World/Platform")
	var wind: WindSystem = game.get_node("WindSystem")
	var anchorless: AnchorlessControlSystem = game.get_node(
		"World/AnchorlessControlSystem"
	) as AnchorlessControlSystem
	var catalog: UpgradeCatalog = game.get_node("UpgradeSystem").catalog
	var overlay: PlatformUpgradeAssetOverlay = game.get_node(
		"World/Platform/PlatformUpgradeAssetOverlay"
	) as PlatformUpgradeAssetOverlay
	assert(platform != null)
	assert(wind != null)
	assert(anchorless != null)
	assert(anchorless.get_parent() == game.get_node("World"))
	assert(catalog != null)
	assert(overlay != null)
	assert(overlay.wind_compensator_asset != null)
	assert(game.get_node_or_null("World/Platform/PlatformWindCompensatorVisual") == null)

	_assert_single_upgrade_overlay(game)
	_assert_single_anchorless_system(game)
	_assert_compensator_layout(overlay.wind_compensator_asset, platform)
	assert(not overlay.is_wind_compensator_visible_for_tests())
	assert(not overlay.get_visible_asset_ids_for_tests().has("wind_compensator"))
	assert(overlay.wind_compensator_asset.get_active_side(anchorless, wind) == 0)

	_apply(anchorless, catalog, &"anchorless_wind_reduction_basic")
	await process_frame
	assert(wind.get_influence_multiplier() < 1.0)
	assert(overlay.is_wind_compensator_visible_for_tests())
	assert(overlay.get_visible_asset_ids_for_tests().has("wind_compensator"))

	wind.set_debug_state(1, 2)
	await process_frame
	assert(overlay.wind_compensator_asset.get_active_side(anchorless, wind) == 1)

	wind.set_debug_state(-1, 2)
	await process_frame
	assert(overlay.wind_compensator_asset.get_active_side(anchorless, wind) == -1)

	wind.set_anchorless_modifiers(1.0, false)
	await process_frame
	assert(overlay.is_wind_compensator_visible_for_tests())
	assert(overlay.wind_compensator_asset.get_active_side(anchorless, wind) == 0)
	wind.reset_anchorless_modifiers()

	anchorless.reset_upgrade_runtime()
	await process_frame
	assert(not overlay.is_wind_compensator_visible_for_tests())
	assert(not overlay.get_visible_asset_ids_for_tests().has("wind_compensator"))

	print("Platform wind compensator scenarios passed")
	quit()


func _assert_base_scene_has_upgrade_overlay() -> void:
	var base_game: Node2D = BASE_GAME_SCENE.instantiate() as Node2D
	assert(base_game != null)
	var overlay: PlatformUpgradeAssetOverlay = base_game.get_node_or_null(
		"World/Platform/PlatformUpgradeAssetOverlay"
	) as PlatformUpgradeAssetOverlay
	var anchorless: AnchorlessControlSystem = base_game.get_node_or_null(
		"World/AnchorlessControlSystem"
	) as AnchorlessControlSystem
	assert(overlay != null)
	assert(overlay.wind_compensator_asset != null)
	assert(anchorless != null)
	_assert_single_upgrade_overlay(base_game)
	_assert_single_anchorless_system(base_game)
	base_game.queue_free()


func _assert_single_upgrade_overlay(game: Node) -> void:
	var overlays: Array[Node] = game.find_children(
		"PlatformUpgradeAssetOverlay",
		"PlatformUpgradeAssetOverlay",
		true,
		false
	)
	assert(overlays.size() == 1)


func _assert_single_anchorless_system(game: Node) -> void:
	var systems: Array[Node] = game.find_children(
		"AnchorlessControlSystem",
		"AnchorlessControlSystem",
		true,
		false
	)
	assert(systems.size() == 1)
	assert(systems[0].name == "AnchorlessControlSystem")
	assert(systems[0].get_parent().name == "World")


func _apply(
	anchorless: AnchorlessControlSystem,
	catalog: UpgradeCatalog,
	card_id: StringName
) -> void:
	var definition: UpgradeDefinition = catalog.get_definition(card_id)
	assert(definition != null)
	assert(anchorless.can_apply_upgrade_effect(definition.effect))
	assert(anchorless.apply_upgrade_effect(definition.effect))


func _assert_compensator_layout(
	asset: PlatformUpgradeWindCompensatorAsset,
	platform: PlatformController
) -> void:
	var draw_size: Vector2 = asset.size
	var centers: Array[Vector2] = asset.get_centers(platform, draw_size)
	var left_center: Vector2 = centers[0]
	var right_center: Vector2 = centers[1]
	var platform_bottom: float = platform.get_platform_height() * 0.5

	assert(asset.base_texture != null)
	assert(asset.active_texture != null)
	assert(draw_size.x > 0.0)
	assert(draw_size.y > 0.0)
	assert(left_center.x < 0.0)
	assert(right_center.x > 0.0)
	assert(is_equal_approx(
		left_center.y - draw_size.y * 0.5,
		platform_bottom + asset.vertical_offset
	))
	assert(is_equal_approx(
		right_center.y - draw_size.y * 0.5,
		platform_bottom + asset.vertical_offset
	))
	assert(left_center.y > platform_bottom)
	assert(right_center.y > platform_bottom)


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
