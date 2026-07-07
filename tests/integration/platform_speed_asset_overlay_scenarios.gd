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

	var overlay: PlatformUpgradeAssetOverlay = game.get_node(
		"World/Platform/PlatformUpgradeAssetOverlay"
	)
	assert(overlay != null)
	assert(not overlay.is_speed_asset_visible())
	assert(overlay.get_speed_engine_count_for_tests() == 0)

	var anchorless := AnchorlessControlSystem.new()
	assert(anchorless.upgrades.apply_flag(AnchorlessControlUpgradeRuntime.SPEED))
	overlay._anchorless = anchorless
	await process_frame

	assert(overlay.is_speed_asset_visible())
	assert(overlay.get_speed_engine_count_for_tests() == 2)
	var base_size: Vector2 = overlay.get_speed_engine_base_size_for_tests()
	var scaled_size: Vector2 = overlay.get_speed_engine_size_for_tests()
	var expected_scale: float = overlay.get_speed_engine_scale_multiplier_for_tests()
	assert(is_equal_approx(expected_scale, 1.15))
	assert(scaled_size.is_equal_approx(base_size * expected_scale))
	assert(overlay.get_speed_flame_size_for_tests().is_equal_approx(scaled_size))

	var core_center: Vector2 = overlay.get_platform_core_center_for_tests()
	var centers: Array[Vector2] = overlay.get_speed_engine_centers_for_tests()
	assert(centers.size() == 2)
	var offset: Vector2 = overlay.get_speed_engine_offset_for_tests()
	assert(offset.x > 52.0)
	assert(offset.x > base_size.x * 0.5)
	assert(is_equal_approx(centers[0].y, core_center.y + offset.y))
	assert(is_equal_approx(centers[1].y, core_center.y + offset.y))
	assert(is_equal_approx((centers[0].x + centers[1].x) * 0.5, core_center.x))
	assert(is_equal_approx(core_center.x - centers[0].x, offset.x))
	assert(is_equal_approx(centers[1].x - core_center.x, offset.x))

	print("Platform speed asset overlay scenarios passed")
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
