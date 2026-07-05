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
	var catalog: UpgradeCatalog = game.get_node("UpgradeSystem").catalog
	var visual: CombatAnchorVisualController = anchors.get_node(
		"AnchorVisualController"
	) as CombatAnchorVisualController
	assert(anchors != null)
	assert(combat != null)
	assert(catalog != null)
	assert(visual != null)
	assert(visual.are_anchor_asset_regions_valid_for_tests())
	assert(visual.get_anchor_visual_z_index_for_tests() >= visual.minimum_z_index)
	for anchor_id: int in range(4):
		assert(visual.is_winch_drawable_for_tests(anchor_id))
		assert(visual.get_winch_asset_id_for_tests(anchor_id) == &"base")

	assert(combat.apply_upgrade_effect(
		catalog.get_definition(CombatAnchorUpgradeRuntime.STRONG).effect
	))
	await process_frame
	assert(visual.is_reinforced_chain_visual_active())
	assert(visual.get_winch_asset_id_for_tests(0) == &"strong")
	for anchor_id: int in range(4):
		assert(visual.is_winch_drawable_for_tests(anchor_id))

	combat.reset_upgrade_runtime()
	assert(combat.apply_upgrade_effect(
		catalog.get_definition(CombatAnchorUpgradeRuntime.TRAP).effect
	))
	await process_frame
	assert(visual.get_winch_asset_id_for_tests(0) == &"specialization_2")
	for anchor_id: int in range(4):
		assert(visual.is_winch_drawable_for_tests(anchor_id))

	print("Anchor visual restoration scenarios passed")
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
