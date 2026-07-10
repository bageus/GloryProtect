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
	_stabilize_world(game)

	var overlay: PlatformUpgradeAssetOverlayStabilityFixed = game.get_node(
		"World/Platform/PlatformUpgradeAssetOverlay"
	) as PlatformUpgradeAssetOverlayStabilityFixed
	var anchorless: AnchorlessControlSystem = game.get_node(
		"World/AnchorlessControlSystem"
	) as AnchorlessControlSystem
	assert(overlay != null)
	assert(anchorless != null)
	assert(anchorless.upgrades.apply_flag(AnchorlessControlUpgradeRuntime.SPEED))
	assert(anchorless.upgrades.apply_scalar(
		AnchorlessControlUpgradeRuntime.WIND_REDUCTION,
		0.2
	))
	await process_frame

	assert(overlay.is_speed_asset_visible())
	assert(overlay.get_speed_engine_count_for_tests() == 2)
	var engine_size: Vector2 = overlay.get_speed_engine_size_for_tests()
	var core_center: Vector2 = overlay.get_platform_core_center_for_tests()
	var centers: Array[Vector2] = overlay.get_speed_engine_centers_for_tests()
	assert(centers.size() == 2)
	assert(is_equal_approx(
		overlay.get_speed_engine_top_for_tests(-1),
		overlay.get_platform_bottom_for_tests()
	))
	assert(is_equal_approx(
		overlay.get_speed_engine_top_for_tests(1),
		overlay.get_platform_bottom_for_tests()
	))
	assert(
		core_center.x - centers[0].x - engine_size.x * 0.5
		> overlay.platform_core_reference_size.x * 0.5
	)
	assert(
		centers[1].x - core_center.x - engine_size.x * 0.5
		> overlay.platform_core_reference_size.x * 0.5
	)
	assert(overlay.get_speed_common_source_rect_for_tests().size.x > 0.0)
	assert(overlay.get_speed_common_source_rect_for_tests().size.y > 0.0)
	assert(overlay.is_wind_compensator_visible_for_tests())
	assert(is_equal_approx(
		overlay.get_wind_compensator_top_for_tests(-1),
		overlay.get_platform_bottom_for_tests()
	))
	assert(is_equal_approx(
		overlay.get_wind_compensator_top_for_tests(1),
		overlay.get_platform_bottom_for_tests()
	))

	print("Anchor platform underside visual scenarios passed")
	quit()


func _stabilize_world(game: Node) -> void:
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
		var system: Node = game.get_node(path)
		system.set_process(false)
		system.set_physics_process(false)
