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

	var overlay: PlatformUpgradeAssetOverlayFeedbackFixed = game.get_node(
		"World/Platform/PlatformUpgradeAssetOverlay"
	) as PlatformUpgradeAssetOverlayFeedbackFixed
	var pulse_visual: ShieldCorePulseVisualAtlasFixed = game.get_node(
		"World/ShieldCorePulseVisual"
	) as ShieldCorePulseVisualAtlasFixed
	assert(overlay != null)
	assert(pulse_visual != null)

	assert(overlay.get_stability_base_asset_path_for_tests() == (
		"res://visual/objects/platform/core/control_stability/"
		+ "stability_control.png"
	))
	assert(overlay.get_stability_overlay_asset_paths_for_tests() == (
		PackedStringArray([
			"res://visual/objects/platform/core/control_stability/overlay_stability_control_01.png",
			"res://visual/objects/platform/core/control_stability/overlay_stability_control_02.png",
			"res://visual/objects/platform/core/control_stability/overlay_stability_control_03.png",
		])
	))
	assert(overlay.get_stability_base_draw_size_for_tests().x > 0.0)
	assert(overlay.get_stability_base_draw_size_for_tests().y > 0.0)
	assert(overlay.get_stability_overlay_draw_size_for_tests().x > 0.0)
	assert(overlay.get_stability_overlay_draw_size_for_tests().y > 0.0)

	assert(is_equal_approx(overlay.get_speed_flame_edge_inset_for_tests(), 11.0))

	assert(pulse_visual.get_ground_pulse_atlas_path_for_tests() == (
		"res://visual/tiles/atlas_ground_core_red.png"
	))
	assert(pulse_visual.get_platform_pulse_atlas_path_for_tests() == (
		"res://visual/tiles/atlas_platform_core_red.png"
	))
	assert(pulse_visual.get_ground_pulse_frame_count_for_tests() == 6)
	assert(pulse_visual.get_platform_pulse_frame_count_for_tests() == 6)
	assert(pulse_visual.get_ground_pulse_frame_for_tests(0.0).size.x > 0.0)
	assert(pulse_visual.get_ground_pulse_frame_for_tests(1.0).size.y > 0.0)
	assert(pulse_visual.get_platform_pulse_frame_for_tests(0.0).size.x > 0.0)
	assert(pulse_visual.get_platform_pulse_frame_for_tests(1.0).size.y > 0.0)

	print("Asset mapping regression scenarios passed")
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
