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

	var wind: WindSystem = game.get_node("WindSystem")
	var anchorless: AnchorlessControlSystem = game.get_node(
		"World/AnchorlessControlSystem"
	) as AnchorlessControlSystem
	var catalog: UpgradeCatalog = game.get_node("UpgradeSystem").catalog
	var overlay: PlatformUpgradeAssetOverlayStabilityFixed = game.get_node(
		"World/Platform/PlatformUpgradeAssetOverlay"
	) as PlatformUpgradeAssetOverlayStabilityFixed
	assert(wind != null)
	assert(anchorless != null)
	assert(catalog != null)
	assert(overlay != null)
	assert(game.get_node_or_null("World/Platform/PlatformWindCompensatorVisual") == null)

	_assert_compensator_layout(overlay)
	assert(not overlay.is_wind_compensator_visible_for_tests())
	assert(not overlay.get_visible_asset_ids_for_tests().has("wind_compensator"))
	assert(overlay.get_wind_compensator_active_side_for_tests() == 0)

	_apply(anchorless, catalog, &"anchorless_wind_reduction_basic")
	await process_frame
	assert(overlay.is_wind_compensator_visible_for_tests())
	assert(overlay.get_visible_asset_ids_for_tests().has("wind_compensator"))

	wind.set_debug_state(1, 2)
	await process_frame
	assert(overlay.get_wind_compensator_active_side_for_tests() == 1)

	wind.set_debug_state(-1, 2)
	await process_frame
	assert(overlay.get_wind_compensator_active_side_for_tests() == -1)

	wind.set_anchorless_modifiers(1.0, false)
	await process_frame
	assert(overlay.get_wind_compensator_active_side_for_tests() == 0)
	wind.reset_anchorless_modifiers()

	anchorless.reset_upgrade_runtime()
	await process_frame
	assert(not overlay.is_wind_compensator_visible_for_tests())
	assert(not overlay.get_visible_asset_ids_for_tests().has("wind_compensator"))

	print("Platform wind compensator scenarios passed")
	quit()


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
	overlay: PlatformUpgradeAssetOverlayStabilityFixed
) -> void:
	var centers: Array[Vector2] = overlay.get_wind_compensator_centers_for_tests()
	var left_center: Vector2 = centers[0]
	var right_center: Vector2 = centers[1]
	assert(left_center.x < 0.0)
	assert(right_center.x > 0.0)
	assert(is_equal_approx(absf(left_center.x), overlay.wind_compensator_offset.x))
	assert(is_equal_approx(right_center.x, overlay.wind_compensator_offset.x))
	assert(is_equal_approx(left_center.y, overlay.wind_compensator_offset.y))
	assert(is_equal_approx(right_center.y, overlay.wind_compensator_offset.y))
	assert(overlay.wind_compensator_size.x > 0.0)
	assert(overlay.wind_compensator_size.y > 0.0)


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
