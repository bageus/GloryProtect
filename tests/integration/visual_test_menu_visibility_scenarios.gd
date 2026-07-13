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

	var panel := VisualUpgradeTestPanelVisibilityControls.new()
	panel.name = "VisualUpgradeTestPanel"
	game.add_child(panel)
	panel.configure(game)
	await process_frame

	var run_toggle: Button = panel.get_node(
		"VisualRunControlsRoot/RunMenuVisibilityToggle"
	) as Button
	var upgrade_toggle: Button = panel.get_node(
		"VisualUpgradeTestRoot/UpgradeMenuVisibilityToggle"
	) as Button
	var run_panel: PanelContainer = panel.get_node(
		"VisualRunControlsRoot/RunControlsPanel"
	) as PanelContainer
	var upgrade_panel: PanelContainer = panel.get_node(
		"VisualUpgradeTestRoot/UpgradeTreePanel"
	) as PanelContainer

	assert(run_toggle != null)
	assert(upgrade_toggle != null)
	assert(run_panel != null)
	assert(upgrade_panel != null)
	assert(run_panel.offset_top > run_toggle.offset_bottom)
	assert(upgrade_panel.offset_top > upgrade_toggle.offset_bottom)
	assert(panel.is_run_menu_visible_for_tests())
	assert(panel.is_upgrade_menu_visible_for_tests())
	assert(panel.get_run_menu_toggle_text_for_tests() == "Скрыть тест забега")
	assert(panel.get_upgrade_menu_toggle_text_for_tests() == "Скрыть тест улучшений")

	run_toggle.emit_signal("pressed")
	assert(not panel.is_run_menu_visible_for_tests())
	assert(panel.is_upgrade_menu_visible_for_tests())
	assert(run_toggle.visible)
	assert(panel.get_run_menu_toggle_text_for_tests() == "Открыть тест забега")

	upgrade_toggle.emit_signal("pressed")
	assert(not panel.is_run_menu_visible_for_tests())
	assert(not panel.is_upgrade_menu_visible_for_tests())
	assert(upgrade_toggle.visible)
	assert(panel.get_upgrade_menu_toggle_text_for_tests() == "Открыть тест улучшений")

	run_toggle.emit_signal("pressed")
	assert(panel.is_run_menu_visible_for_tests())
	assert(not panel.is_upgrade_menu_visible_for_tests())
	upgrade_toggle.emit_signal("pressed")
	assert(panel.is_run_menu_visible_for_tests())
	assert(panel.is_upgrade_menu_visible_for_tests())

	panel.set_run_menu_visible_for_tests(false)
	panel.set_upgrade_menu_visible_for_tests(true)
	assert(not panel.is_run_menu_visible_for_tests())
	assert(panel.is_upgrade_menu_visible_for_tests())

	print("Visual test menu visibility scenarios passed")
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
