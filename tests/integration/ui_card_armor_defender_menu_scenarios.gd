extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var flow: GameFlowController = game.get_node("GameFlowController")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var roles := game.get_node(
		"World/Platform/CrewRoleManager"
	) as ShooterCrewRoleManagerPolished
	var selection := game.get_node("CrewDebugInput") as CrewSelectionController
	var crew_panel := game.get_node(
		"CanvasLayer/PrototypeHUD/CrewCommandPanel"
	) as CrewCommandPanelPlacementPolished
	var economy: RunEconomy = game.get_node("RunEconomy")
	var upgrade_panel := game.get_node(
		"CanvasLayer/UpgradeSelectionPanel"
	) as UpgradeSelectionPanel

	_disable_spawners(game)
	flow.state = GameFlowController.RunState.RUNNING
	await process_frame

	var defender: Defender = crew.get_defender(0)
	var visual := defender.visual as DefenderVisualPolished
	assert(visual != null)
	assert(visual.get_max_armor_segments() == 0)
	defender.durability.set_max_armor(3)
	await process_frame
	assert(visual.get_max_armor_segments() == 3)
	assert(visual.get_current_armor_segments() == 3)
	defender.health.apply_damage(1, &"test_armor_ui")
	await process_frame
	assert(visual.get_current_armor_segments() == 2)

	assert(crew.apply_shooter_flag(&"shooter_role_unlocked"))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = (
		game.get_viewport().get_canvas_transform() * defender.global_position
	)
	selection.call("_handle_world_click", click)
	await process_frame
	assert(crew_panel._view.is_context_visible())
	var buttons: PackedStringArray = crew_panel._view.get_context_button_texts()
	assert(buttons.has("Боец"))
	assert(buttons.has("Стрелок"))
	assert(buttons.has("Свободная боевая ячейка"))
	assert(_contains_button_prefix(buttons, "УПРАВЛЕНИЕ"))
	assert(_contains_button_prefix(buttons, "ЛЕВЫЙ ЯКОРЬ"))
	assert(_contains_button_prefix(buttons, "ПРАВЫЙ ЯКОРЬ"))

	var before: CrewAssignmentRuntime = roles.get_assignment(defender.defender_id)
	assert(before.current_role == CrewRole.Id.DRIVER)
	assert(crew_panel.request_defender_type(
		defender.defender_id,
		CrewRole.Id.SHOOTER
	))
	await process_frame
	var after: CrewAssignmentRuntime = roles.get_assignment(defender.defender_id)
	assert(after.current_role == CrewRole.Id.DRIVER)
	assert(roles.get_combat_role(defender.defender_id) == CrewRole.Id.SHOOTER)

	economy.add_coins(100, &"test_card_ui")
	await process_frame
	assert(upgrade_panel.visible)
	assert(upgrade_panel.get_offer_text().begins_with("Уровень "))
	assert(not upgrade_panel.get_offer_text().contains("ВЫБЕРИТЕ"))
	assert(not upgrade_panel.get_offer_text().contains("ВЫДАЧА"))
	assert(not upgrade_panel.get_mode_text().contains("СОБЫТИЕ"))
	assert(upgrade_panel.get_cost_text().is_valid_int())
	assert(not upgrade_panel.has_node(
		"Center/Panel/Margin/VBox/InfoLabel"
	))
	for card_index: int in range(upgrade_panel.get_rendered_card_count()):
		var text: String = upgrade_panel.get_rendered_card_text(card_index)
		var lines: PackedStringArray = text.split("\n")
		assert(not lines.is_empty())
		assert(lines[0] not in ["1", "2", "3"])
		assert(not text.contains("ЭФФЕКТ"))
		assert(not text.contains("ТРЕБОВАНИЯ"))
		assert(not text.contains("Заблокирует альтернативы"))
		assert(not text.contains("Нет требований"))

	print("Card, armor, and defender menu scenarios passed")
	quit()


func _contains_button_prefix(
	buttons: PackedStringArray,
	prefix: String
) -> bool:
	for text: String in buttons:
		if text.begins_with(prefix):
			return true
	return false


func _disable_spawners(game: Node) -> void:
	var paths: Array[NodePath] = [
		NodePath("World/BoardingSpawnDirector"),
		NodePath("World/FlyingEnemySpawnDirector"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
	]
	for path: NodePath in paths:
		if not game.has_node(path):
			continue
		var node: Node = game.get_node(path)
		node.set_process(false)
		node.set_physics_process(false)
