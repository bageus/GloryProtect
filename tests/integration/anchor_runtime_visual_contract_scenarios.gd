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

	var anchors: CombatAnchorHostSystem = game.get_node("World/AnchorSystem")
	var combat: CombatAnchorSystem = game.get_node("World/CombatAnchorSystem")
	var visual: CombatAnchorVisualController = anchors.get_node(
		"AnchorVisualController"
	) as CombatAnchorVisualController
	assert(anchors != null)
	assert(combat != null)
	assert(visual != null)
	assert(visual.visible)
	assert(visual.is_inside_tree())
	assert(visual.get_anchor_visual_z_index_for_tests() >= visual.minimum_z_index)
	for anchor_id: int in range(4):
		assert(visual.is_winch_drawable_for_tests(anchor_id))
		assert(visual.get_winch_asset_id_for_tests(anchor_id) == &"base")
		assert(not visual.get_winch_chain_exit(anchor_id).is_equal_approx(
			anchors.get_platform_attachment_world(anchor_id)
		))

	assert(combat.upgrades.apply_flag(CombatAnchorUpgradeRuntime.STRONG))
	await process_frame
	assert(visual.get_winch_asset_id_for_tests(0) == &"strong")
	assert(visual.is_reinforced_chain_visual_active())
	for anchor_id: int in range(4):
		assert(visual.is_winch_drawable_for_tests(anchor_id))

	combat.upgrades.reset()
	assert(combat.upgrades.apply_flag(CombatAnchorUpgradeRuntime.TRAP))
	await process_frame
	assert(visual.get_winch_asset_id_for_tests(0) == &"specialization_2")
	for anchor_id: int in range(4):
		assert(visual.is_winch_drawable_for_tests(anchor_id))

	print("Anchor runtime visual contract scenarios passed")
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
