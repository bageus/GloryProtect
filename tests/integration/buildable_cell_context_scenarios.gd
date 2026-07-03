extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run_scenario")


func _run_scenario() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	flow.state = GameFlowController.RunState.RUNNING
	_disable_spawners(game)
	await process_frame

	var inventory: BuildableInventory = game.get_node("BuildableInventory")
	var grid: BuildableGrid = game.get_node("World/BuildableGrid")
	var controller: BuildablePlacementController = game.get_node(
		"BuildablePlacementController"
	)
	var legacy_panel: BuildablePlacementPanel = game.get_node(
		"CanvasLayer/BuildablePlacementPanel"
	)
	var context_panel: UnifiedContextCrewCommandPanel = game.get_node(
		"CanvasLayer/PrototypeHUD/CrewCommandPanel"
	)
	var medical: MedicalStationSystem = game.get_node(
		"World/MedicalStationSystem"
	)

	inventory.unlock(BuildableType.Id.MEDICAL_STATION)
	inventory.unlock(BuildableType.Id.TURRET, 2)
	await process_frame
	assert(not legacy_panel.visible)
	assert(not context_panel.is_context_visible())
	assert(not controller.is_grid_preview_visible())

	var medical_cell: int = 3
	assert(grid.balance.is_medical_cell(medical_cell))
	assert(controller.select_empty_cell(medical_cell))
	await process_frame
	_assert_context_buttons(
		context_panel,
		PackedStringArray(["Медпост 0/1", "Турель 0/2"])
	)
	assert(not _context_text(context_panel).contains("Выберите объект для клетки"))
	assert(not legacy_panel.visible)
	assert(controller.place_type_in_selected_cell(BuildableType.Id.MEDICAL_STATION))
	await process_frame

	var medical_id: int = grid.get_buildable_id_by_type(
		BuildableType.Id.MEDICAL_STATION
	)
	assert(medical_id >= 0)
	assert(medical.has_station())
	assert(grid.get_buildable_id_at_cell(medical_cell) == medical_id)
	assert(grid.get_buildable_id_at_cell(medical_cell + 1) == -1)
	assert(not context_panel.is_context_visible())
	assert(not legacy_panel.visible)
	assert(controller.select_buildable(medical_id))
	await process_frame
	_assert_context_buttons(context_panel, PackedStringArray(["Демонтировать"]))
	assert(not context_panel.get_context_button_texts().has("Перенести"))
	assert(not legacy_panel.visible)

	var turret_cell: int = 4
	assert(controller.select_empty_cell(turret_cell))
	await process_frame
	_assert_context_buttons(context_panel, PackedStringArray(["Турель 0/2"]))
	assert(not context_panel.get_context_button_texts().has("Медпост 1/1"))
	assert(not legacy_panel.visible)
	assert(controller.place_type_in_selected_cell(BuildableType.Id.TURRET))
	await process_frame

	var turret_ids: Array[int] = grid.get_buildable_ids_by_type(
		BuildableType.Id.TURRET
	)
	assert(turret_ids.size() == 1)
	var turret_id: int = turret_ids[0]
	assert(not context_panel.is_context_visible())
	assert(controller.select_buildable(turret_id))
	await process_frame
	_assert_context_buttons(
		context_panel,
		PackedStringArray(["Перенести", "Демонтировать"])
	)
	assert(controller.begin_move_selected())
	await process_frame
	assert(controller.is_grid_preview_visible())
	_assert_context_buttons(context_panel, PackedStringArray(["Отмена"]))
	assert(grid.move(turret_id, 5))
	controller.clear_selection()
	await process_frame
	assert(grid.get_snapshot(turret_id).cell_index == 5)
	assert(not controller.is_grid_preview_visible())
	assert(not context_panel.is_context_visible())
	assert(not legacy_panel.visible)

	assert(controller.select_buildable(turret_id))
	await process_frame
	assert(controller.demolish_selected())
	assert(not grid.has_buildable(turret_id))
	assert(not context_panel.is_context_visible())
	assert(not legacy_panel.visible)

	print("Buildable cell context scenarios passed")
	quit()


func _assert_context_buttons(
	panel: UnifiedContextCrewCommandPanel,
	expected: PackedStringArray
) -> void:
	assert(panel.is_context_visible())
	var buttons: PackedStringArray = panel.get_context_button_texts()
	for text: String in expected:
		assert(buttons.has(text))
	_assert_context_hud_geometry(panel._view)
	_assert_context_buttons_clickable(panel._view)


func _assert_context_hud_geometry(view: CrewCommandPanelView) -> void:
	assert(view.get_context_center_offset_x() <= -300.0)
	assert(view.get_context_rect().size.x <= 370.0)
	assert(view.get_context_background_alpha() <= 0.76)
	assert(view.get_context_button_background_alpha() >= 0.3)
	assert(view.get_context_panel_z_index() >= 30)


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


func _context_text(panel: UnifiedContextCrewCommandPanel) -> String:
	var result := ""
	for text: String in panel.get_context_button_texts():
		result += text + "\n"
	return result


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
