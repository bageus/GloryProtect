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
	_stabilize_world(game)
	await process_frame

	var inventory: BuildableInventory = game.get_node("BuildableInventory")
	var grid: BuildableGrid = game.get_node("World/BuildableGrid")
	var platform: PlatformController = game.get_node("World/Platform")
	var controller: BuildablePlacementController = game.get_node(
		"BuildablePlacementController"
	)
	var legacy_panel: BuildablePlacementPanel = game.get_node(
		"CanvasLayer/BuildablePlacementPanel"
	)
	var context_panel: UnifiedContextCrewCommandPanel = game.get_node(
		"CanvasLayer/PrototypeHUD/CrewCommandPanel"
	)
	var upgrade_panel: UpgradeSelectionPanel = game.get_node(
		"CanvasLayer/UpgradeSelectionPanel"
	)
	var medical: MedicalStationSystem = game.get_node(
		"World/MedicalStationSystem"
	)
	var turrets: TurretSystem = game.get_node("World/TurretSystem")
	var roles: CrewRoleManager = game.get_node(
		"World/Platform/CrewRoleManager"
	)

	assert(not upgrade_panel.z_as_relative)
	assert(upgrade_panel.z_index > legacy_panel.z_index)
	assert(not legacy_panel.visible)
	assert(not context_panel.is_context_visible())
	assert(not controller.is_grid_preview_visible())

	var locked_cell: int = 3
	assert(controller.handle_primary_click(
		platform.get_cell_canvas_center(locked_cell)
	))
	await process_frame
	assert(context_panel.is_context_visible())
	_assert_context_actions(context_panel, PackedStringArray())
	assert(not legacy_panel.visible)
	controller.clear_selection()
	await process_frame

	inventory.unlock(BuildableType.Id.MEDICAL_STATION)
	inventory.unlock(BuildableType.Id.TURRET, 2)
	await process_frame
	assert(not legacy_panel.visible)

	var medical_cell: int = 2
	assert(controller.handle_primary_click(
		platform.get_cell_canvas_center(medical_cell)
	))
	await process_frame
	_assert_context_actions(
		context_panel,
		PackedStringArray(["Медпост 0/1", "Турель 0/2"])
	)
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

	assert(controller.handle_primary_click(
		platform.get_cell_canvas_center(medical_cell)
	))
	await process_frame
	assert(controller.get_selected_buildable_id() == medical_id)
	_assert_context_actions(context_panel, PackedStringArray(["Демонтировать"]))
	assert(not context_panel.get_context_button_texts().has("Перенести"))
	assert(not legacy_panel.visible)
	controller.clear_selection()
	await process_frame

	var turret_cell: int = 3
	assert(controller.handle_primary_click(
		platform.get_cell_canvas_center(turret_cell)
	))
	await process_frame
	_assert_context_actions(context_panel, PackedStringArray(["Турель 0/2"]))
	assert(not context_panel.get_context_button_texts().has("Медпост 1/1"))
	assert(controller.place_type_in_selected_cell(BuildableType.Id.TURRET))
	await process_frame

	var turret_ids: Array[int] = grid.get_buildable_ids_by_type(
		BuildableType.Id.TURRET
	)
	assert(turret_ids.size() == 1)
	var turret_id: int = turret_ids[0]
	assert(turrets.has_turret(turret_id))
	assert(not context_panel.is_context_visible())

	assert(controller.handle_primary_click(
		platform.get_cell_canvas_center(turret_cell)
	))
	await process_frame
	assert(controller.get_selected_buildable_id() == turret_id)
	_assert_context_actions(
		context_panel,
		PackedStringArray(["Перенести", "Демонтировать"])
	)
	assert(controller.begin_move_selected())
	assert(controller.get_mode() == BuildablePlacementController.Mode.MOVE)
	assert(controller.is_grid_preview_visible())

	var moved_cell: int = 4
	assert(controller.handle_primary_click(
		platform.get_cell_canvas_center(moved_cell)
	))
	await process_frame
	assert(grid.get_snapshot(turret_id).cell_index == moved_cell)
	assert(is_equal_approx(
		roles.get_role_target_x(CrewRole.Id.TURRET, 0, turret_id),
		platform.get_cell_local_x(moved_cell)
	))
	assert(not controller.is_grid_preview_visible())
	assert(not context_panel.is_context_visible())

	flow.state = GameFlowController.RunState.MANUAL_PAUSE
	await process_frame
	assert(controller.handle_primary_click(
		platform.get_cell_canvas_center(5)
	))
	assert(controller.is_feedback_error())
	flow.state = GameFlowController.RunState.RUNNING
	await process_frame

	assert(controller.handle_primary_click(
		platform.get_cell_canvas_center(moved_cell)
	))
	await process_frame
	assert(controller.demolish_selected())
	assert(not grid.has_buildable(turret_id))
	assert(not turrets.has_turret(turret_id))
	assert(not context_panel.is_context_visible())

	assert(controller.handle_primary_click(
		platform.get_cell_canvas_center(medical_cell)
	))
	await process_frame
	assert(controller.demolish_selected())
	assert(not grid.has_buildable(medical_id))
	assert(not medical.has_station())
	assert(not context_panel.is_context_visible())
	assert(not legacy_panel.visible)

	print("Buildable placement UI scenarios passed")
	quit()


func _assert_context_actions(
	panel: UnifiedContextCrewCommandPanel,
	expected: PackedStringArray
) -> void:
	assert(panel.is_context_visible())
	var buttons: PackedStringArray = panel.get_context_button_texts()
	for text: String in expected:
		assert(buttons.has(text))
	assert(not "\n".join(buttons).contains("Выберите объект для клетки"))
	_assert_context_position_and_click_targets(panel)


func _assert_context_position_and_click_targets(
	panel: UnifiedContextCrewCommandPanel
) -> void:
	var host_rect: Rect2 = panel.get_global_rect()
	var context_rect: Rect2 = panel._view._context_panel.get_global_rect()
	_assert_rect_inside(context_rect, host_rect)
	assert(panel._view.get_context_center_offset_x() < -40.0)
	assert(context_rect.get_center().x < host_rect.get_center().x - 40.0)
	assert(panel._view.get_context_background_alpha() <= 0.82)
	var button_rects: Array[Rect2] = panel._view.get_enabled_context_button_rects()
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


func _stabilize_world(game: Node) -> void:
	var paths: Array[NodePath] = [
		NodePath("World/BoardingSpawnDirector"),
		NodePath("World/FlyingEnemySpawnDirector"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
	]
	for path: NodePath in paths:
		if not game.has_node(path):
			continue
		var system: Node = game.get_node(path)
		system.set_process(false)
		system.set_physics_process(false)
