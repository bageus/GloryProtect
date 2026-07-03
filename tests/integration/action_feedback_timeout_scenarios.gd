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

	var panel: UnifiedContextCrewCommandPanel = game.get_node(
		"CanvasLayer/PrototypeHUD/CrewCommandPanel"
	)
	assert(panel != null)
	var view: CrewCommandPanelView = panel._view
	assert(view != null)
	assert(not view.is_feedback_visible())

	panel.call("_set_feedback", "Первое действие", false)
	assert(view.is_feedback_visible())
	assert(view.get_feedback_text() == "Первое действие")

	var delay: float = view.get_feedback_auto_hide_seconds()
	await create_timer(maxf(0.1, delay - 0.15)).timeout
	panel.call("_set_feedback", "Новое действие", false)
	await create_timer(0.2).timeout
	assert(view.is_feedback_visible())
	assert(view.get_feedback_text() == "Новое действие")

	await create_timer(delay + 0.1).timeout
	assert(not view.is_feedback_visible())
	assert(view.get_feedback_text().is_empty())

	panel.call("_set_feedback", "Пауза тоже стабильна", false)
	flow.state = GameFlowController.RunState.MANUAL_PAUSE
	await create_timer(delay + 0.1).timeout
	assert(not view.is_feedback_visible())

	panel.call("_set_feedback", "Сообщение до очистки", false)
	assert(view.is_feedback_visible())
	view.clear_feedback()
	await create_timer(delay + 0.1).timeout
	assert(not view.is_feedback_visible())
	assert(view.get_feedback_text().is_empty())

	print("Action feedback timeout scenarios passed")
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
