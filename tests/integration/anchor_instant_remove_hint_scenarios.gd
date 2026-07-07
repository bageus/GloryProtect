extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame
	_disable_spawners(game)
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.state = GameFlowController.RunState.RUNNING
	paused = false

	var anchors: CombatAnchorHostSystem = game.get_node("World/AnchorSystem")
	var hud: PrototypeHUD = game.get_node("CanvasLayer/PrototypeHUD")
	assert(anchors != null)
	assert(hud != null)
	await process_frame
	assert(not hud.is_instant_anchor_remove_prompt_visible_for_tests())

	_attach_anchor_for_tests(anchors, 0)
	await process_frame
	assert(anchors.get_active_path_count() == 1)
	assert(not hud.is_instant_anchor_remove_prompt_visible_for_tests())

	anchors.set_combat_anchor_modifiers(0.0, 0.0, 1.0, true)
	await process_frame
	assert(anchors.is_instant_remove_all_enabled())
	assert(hud.is_instant_anchor_remove_prompt_visible_for_tests())
	assert(hud.get_instant_anchor_remove_prompt_text_for_tests().contains(
		AppSettings.get_binding_text(&"gp_anchor_remove_all")
	))
	assert(hud.get_instant_anchor_remove_prompt_text_for_tests().contains(
		"быстро снять все тросы"
	))

	AppSettings.rebind_action(&"gp_anchor_remove_all", KEY_Y, false)
	await process_frame
	assert(hud.get_instant_anchor_remove_prompt_text_for_tests().contains(
		AppSettings.get_binding_text(&"gp_anchor_remove_all")
	))

	anchors.request_remove_all()
	await process_frame
	assert(anchors.get_active_path_count() == 0)
	assert(not hud.is_instant_anchor_remove_prompt_visible_for_tests())
	AppSettings.rebind_action(&"gp_anchor_remove_all", KEY_R, false)

	print("Anchor instant remove hint scenarios passed")
	quit()


func _attach_anchor_for_tests(
	anchors: CombatAnchorHostSystem,
	anchor_id: int
) -> void:
	var store: AnchorRuntimeStore = anchors.get("_store") as AnchorRuntimeStore
	assert(store != null)
	store.set_install_target(anchor_id, anchor_id, Vector2(0.0, 0.0))
	store.attach(anchor_id, anchors.global_position.x)


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
