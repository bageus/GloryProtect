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

	assert(not game.has_node("World/AnchorAssetPresentation"))
	assert(not game.has_node("World/Platform/PlatformAnchorWinchVisual"))
	var anchors: CombatAnchorHostSystem = game.get_node("World/AnchorSystem")
	var rope_visual: CombatAnchorVisualController = anchors.get_node(
		"AnchorVisualController"
	) as CombatAnchorVisualController
	var platform_visual: PlatformVisualController = game.get_node(
		"World/Platform/PlatformVisualController"
	) as PlatformVisualController
	assert(rope_visual != null)
	assert(rope_visual.visible)
	assert(rope_visual.get_anchor_visual_z_index_for_tests() >= 80)
	assert(rope_visual.are_anchor_asset_regions_valid_for_tests())
	assert(platform_visual != null)
	assert(platform_visual.visible)
	assert(platform_visual.get_anchor_winch_count_for_tests() == 4)
	assert(platform_visual.is_anchor_winch_drawable_for_tests())

	print("Anchor visual layer scenarios passed")
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
