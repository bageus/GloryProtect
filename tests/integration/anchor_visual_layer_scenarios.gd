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
	var anchors: CombatAnchorHostSystem = game.get_node("World/AnchorSystem")
	var visual: CombatAnchorVisualController = anchors.get_node(
		"AnchorVisualController"
	) as CombatAnchorVisualController
	assert(visual != null)
	assert(visual.visible)
	assert(visual.get_anchor_visual_z_index_for_tests() >= 80)
	assert(visual.are_anchor_asset_regions_valid_for_tests())
	for anchor_id: int in range(4):
		assert(visual.is_winch_drawable_for_tests(anchor_id))
	assert(visual.get_winch_asset_id_for_tests(0) == &"base")

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
