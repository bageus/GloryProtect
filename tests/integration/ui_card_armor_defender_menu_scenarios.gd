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
	var minimap := game.get_node(
		"CanvasLayer/StrategicMinimap"
	) as StrategicMinimap
	var economy: RunEconomy = game.get_node("RunEconomy")
	var upgrade_panel := game.get_node(
		"CanvasLayer/UpgradeSelectionPanel"
	) as UpgradeSelectionPanel

	_disable_spawners(game)
	flow.state = GameFlowController.RunState.RUNNING
	await process_frame

	_assert_compact_minimap(minimap)
	_assert_crew_slots_inside_viewport(crew_panel)

	var defender: Defender = crew.get_defender(0)
	var visual := defender.visual as DefenderVisualPolished
	assert(visual != null)
	assert(visual.get_max_armor_segments() == 0)
	assert(not visual.has_visible_armor_segments())
	defender.durability.set_max_armor(3)
	await process_frame
	assert(visual.get_max_armor_segments() == 3)
	assert(visual.get_current_armor_segments() == 3)
	assert(visual.has_visible_armor_segments())
	defender.health.apply_damage(1, &"test_armor_ui")
	await process_frame
	assert(visual.get_current_armor_segments() == 2)
	defender.health.apply_damage(2, &"test_armor_ui_empty")
	await process_frame
	assert(visual.get_current_armor_segments() == 0)
	assert(not visual.has_visible_armor_segments())
	defender.durability.restore_armor(1)
	await process_frame
	assert(visual.get_current_armor_segments() == 1)
	assert(visual.has_visible_armor_segments())

	assert(crew.apply_shooter_flag(&"shooter_role_unlocked"))
	assert(selection.select_defender_at_screen_position(
		defender.get_global_transform_with_canvas().origin
	))
	await process_frame
	assert(crew_panel._view.is_context_visible())
	_assert_defender_context_inside_viewport(crew_panel)
	_assert_context_buttons_clickable(crew_panel._view)
	var buttons: PackedStringArray = _collect_button_texts(
		crew_panel._view._context_box
	)
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
	assert(not upgrade_panel.is_global_cost_visible())
	assert(not upgrade_panel.has_node(
		"Center/Panel/Margin/VBox/InfoLabel"
	))
	var first_price_y: float = INF
	for card_index: int in range(upgrade_panel.get_rendered_card_count()):
		var text: String = upgrade_panel.get_rendered_card_text(card_index)
		var lines: PackedStringArray = text.split("\n")
		assert(not lines.is_empty())
		assert(not ["1", "2", "3"].has(lines[0]))
		assert(upgrade_panel.get_rendered_card_price_text(card_index).begins_with(
			"Цена: "
		))
		assert(upgrade_panel.get_rendered_card_price_color(card_index).is_equal_approx(
			UpgradeCardFormatter.get_price_color()
		))
		var price_y: float = upgrade_panel.get_rendered_card_price_global_y(card_index)
		assert(is_finite(price_y))
		if is_inf(first_price_y):
			first_price_y = price_y
		else:
			assert(absf(first_price_y - price_y) <= 2.0)
		assert(not upgrade_panel.has_rendered_card_label(card_index, "BranchLabel"))
		assert(not upgrade_panel.has_rendered_card_label(card_index, "EffectLabel"))
		assert(upgrade_panel.has_rendered_card_label(card_index, "ContentCenter"))
		assert(not text.contains("ЭФФЕКТ"))
		assert(not text.contains("ТРЕБОВАНИЯ"))
		assert(not text.contains("Модификатор:"))
		assert(not text.contains("Активирует новое правило"))
		assert(not text.contains("Заблокирует альтернативы"))
		assert(not text.contains("Нет требований"))

	print("Card, armor, defender menu, and compact HUD scenarios passed")
	quit()


func _assert_compact_minimap(minimap: StrategicMinimap) -> void:
	assert(minimap != null)
	assert(not minimap.has_node("TitleLabel"))
	assert(not minimap.has_node("NextWaveLabel"))
	var summary: Label = minimap.get_node("SummaryLabel") as Label
	var coins: Label = minimap.get_node(
		"StatsPanel/Margin/VBox/CoinsLabel"
	) as Label
	var level: Label = minimap.get_node(
		"StatsPanel/Margin/VBox/UpgradeLevelLabel"
	) as Label
	assert(summary.text.begins_with("Волна: "))
	assert(not summary.text.contains("Группы"))
	assert(not summary.text.contains("Следующая"))
	assert(not summary.text.contains("размер"))
	assert(coins.text.begins_with("Монеты: "))
	assert(level.text.begins_with("Уровень: "))
	assert(is_equal_approx(
		minimap.get_map_width(),
		minimap.size.x * 5.0 / 6.0
	))


func _assert_crew_slots_inside_viewport(
	crew_panel: CrewCommandPanelPlacementPolished
) -> void:
	var host_rect: Rect2 = crew_panel.get_global_rect()
	for button: Button in crew_panel._view._slot_buttons:
		_assert_rect_inside(button.get_global_rect(), host_rect)


func _assert_defender_context_inside_viewport(
	crew_panel: CrewCommandPanelPlacementPolished
) -> void:
	var host_rect: Rect2 = crew_panel.get_global_rect()
	var context_rect: Rect2 = crew_panel._view._context_panel.get_global_rect()
	_assert_rect_inside(context_rect, host_rect)
	assert(crew_panel._view.get_context_center_offset_x() <= -300.0)
	assert(context_rect.get_center().x < host_rect.get_center().x - 180.0)
	assert(context_rect.size.x <= 370.0)
	assert(crew_panel._view.get_context_background_alpha() <= 0.76)
	assert(crew_panel._view.get_context_button_background_alpha() >= 0.3)
	assert(crew_panel._view.get_context_panel_z_index() >= 30)


func _assert_context_buttons_clickable(view: CrewCommandPanelView) -> void:
	var context_rect: Rect2 = view._context_panel.get_global_rect()
	var button_rects: Array[Rect2] = view.get_enabled_context_button_rects()
	assert(not button_rects.is_empty())
	for rect: Rect2 in button_rects:
		assert(rect.size.x > 1.0)
		assert(rect.size.y > 1.0)
		_assert_rect_inside(rect, context_rect.grow(1.0))


func _assert_rect_inside(rect: Rect2, bounds: Rect2) -> void:
	const EPSILON := 1.0
	assert(rect.position.x >= bounds.position.x - EPSILON)
	assert(rect.position.y >= bounds.position.y - EPSILON)
	assert(rect.end.x <= bounds.end.x + EPSILON)
	assert(rect.end.y <= bounds.end.y + EPSILON)


func _collect_button_texts(node: Node) -> PackedStringArray:
	var result := PackedStringArray()
	_collect_button_texts_recursive(node, result)
	return result


func _collect_button_texts_recursive(node: Node, result: PackedStringArray) -> void:
	if node is Button:
		result.append((node as Button).text)
	for child: Node in node.get_children():
		_collect_button_texts_recursive(child, result)


func _contains_button_prefix(buttons: PackedStringArray, prefix: String) -> bool:
	for text: String in buttons:
		if text.begins_with(prefix):
			return true
	return false


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
