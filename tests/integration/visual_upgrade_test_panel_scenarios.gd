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

	var panel := VisualUpgradeTestPanel.new()
	game.add_child(panel)
	panel.configure(game)
	await process_frame
	assert(panel.is_test_panel_ready_for_tests())
	assert(panel.get_toggle_count_for_tests() > 0)
	assert(panel.is_card_ui_suppressed_for_tests())
	flow.begin_card_selection()
	await process_frame
	assert(panel.is_card_ui_suppressed_for_tests())
	assert(flow.state == GameFlowController.RunState.RUNNING)

	assert(panel.get_parent_card_id_for_tests(
		&"shield_contact_advanced"
	) == &"shield_contact_basic")
	assert(panel.get_item_depth_for_tests(
		&"shield_contact_advanced"
	) > panel.get_item_depth_for_tests(&"shield_contact_basic"))
	assert(panel.get_item_visible_text_for_tests(
		&"shield_contact_basic"
	) == "Расширенный контакт")
	assert(panel.get_item_visible_text_for_tests(
		&"shield_contact_advanced"
	) == "Мега-контакт")
	assert(not panel.get_item_visible_text_for_tests(
		&"shield_contact_basic"
	).contains("Открывает"))
	assert(not panel.get_item_visible_text_for_tests(
		&"shield_contact_advanced"
	).contains("Требуется"))
	assert(panel.get_item_description_for_tests(
		&"shield_contact_basic"
	).contains("Открывает: Мега-контакт"))
	assert(panel.get_item_description_for_tests(
		&"shield_contact_advanced"
	).contains("Требуется: Расширенный контакт"))
	assert(panel.is_item_dimmed_for_tests(&"shield_contact_advanced"))
	assert(not panel.toggle_upgrade_for_tests(&"shield_contact_advanced", true))
	assert(not panel.is_upgrade_selected_for_tests(&"shield_contact_advanced"))
	assert(panel.toggle_upgrade_for_tests(&"shield_contact_basic", true))
	assert(not panel.is_item_dimmed_for_tests(&"shield_contact_advanced"))
	assert(panel.toggle_upgrade_for_tests(&"shield_contact_advanced", true))
	assert(panel.is_upgrade_selected_for_tests(&"shield_contact_advanced"))
	assert(panel.toggle_upgrade_for_tests(&"shield_contact_basic", false))
	assert(not panel.is_upgrade_selected_for_tests(&"shield_contact_basic"))
	assert(not panel.is_upgrade_selected_for_tests(&"shield_contact_advanced"))

	var shield_core: ShieldCoreSystem = game.get_node("World/ShieldCoreSystem")
	assert(not shield_core.upgrades.has_distributed_specialization())
	assert(panel.toggle_upgrade_for_tests(
		ShieldCoreUpgradeRuntime.DISTRIBUTED,
		true
	))
	await process_frame
	assert(shield_core.upgrades.has_distributed_specialization())
	assert(panel.toggle_upgrade_for_tests(
		ShieldCoreUpgradeRuntime.DISTRIBUTED,
		false
	))
	await process_frame
	assert(not shield_core.upgrades.has_distributed_specialization())
	assert(panel.is_card_ui_suppressed_for_tests())

	print("Visual upgrade test panel scenarios passed")
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
