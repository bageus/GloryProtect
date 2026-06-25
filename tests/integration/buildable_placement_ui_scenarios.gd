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
	var controller: BuildablePlacementController = game.get_node("BuildablePlacementController")
	var panel: BuildablePlacementPanel = game.get_node("CanvasLayer/BuildablePlacementPanel")
	var medical: MedicalStationSystem = game.get_node("World/MedicalStationSystem")
	var turrets: TurretSystem = game.get_node("World/TurretSystem")
	var roles: CrewRoleManager = game.get_node("World/Platform/CrewRoleManager")

	inventory.unlock(BuildableType.Id.MEDICAL_STATION)
	inventory.unlock(BuildableType.Id.TURRET, 2)
	await process_frame
	assert(not panel.visible)
	assert(not controller.is_grid_preview_visible())

	var medical_cell: int = grid.balance.get_medical_cell_indices()[0]
	assert(controller.handle_primary_click(platform.get_cell_canvas_center(medical_cell)))
	await process_frame
	assert(panel.visible)
	assert(controller.get_selected_cell_index() == medical_cell)
	assert(panel.get_medical_button().visible)
	assert(not panel.get_turret_button().visible)
	assert(not controller.is_grid_preview_visible())
	panel.get_medical_button().pressed.emit()
	await process_frame
	var medical_id := grid.get_buildable_id_by_type(BuildableType.Id.MEDICAL_STATION)
	assert(medical_id >= 0)
	assert(medical.has_station())
	assert(not panel.visible)

	assert(controller.handle_primary_click(platform.get_cell_canvas_center(7)))
	await process_frame
	assert(controller.get_selected_buildable_id() == medical_id)
	assert(panel.get_demolish_button().visible)
	assert(not panel.get_move_button().visible)
	assert(not controller.begin_move_selected())

	controller.clear_selection()
	var turret_cell := 3
	assert(controller.handle_primary_click(platform.get_cell_canvas_center(turret_cell)))
	await process_frame
	assert(panel.visible)
	assert(panel.get_turret_button().visible)
	assert(not panel.get_medical_button().visible)
	panel.get_turret_button().pressed.emit()
	await process_frame
	var turret_id: int = grid.get_buildable_ids_by_type(BuildableType.Id.TURRET)[0]
	assert(turrets.has_turret(turret_id))
	assert(not panel.visible)

	assert(controller.handle_primary_click(platform.get_cell_canvas_center(turret_cell)))
	await process_frame
	assert(panel.get_move_button().visible)
	panel.get_move_button().pressed.emit()
	assert(controller.get_mode() == BuildablePlacementController.Mode.MOVE)
	assert(controller.is_grid_preview_visible())
	assert(controller.handle_primary_click(platform.get_cell_canvas_center(4)))
	await process_frame
	assert(grid.get_snapshot(turret_id).cell_index == 4)
	assert(not controller.is_grid_preview_visible())
	assert(not panel.visible)
	assert(is_equal_approx(
		roles.get_role_target_x(CrewRole.Id.TURRET, 0, turret_id),
		platform.get_cell_local_x(4)
	))

	flow.state = GameFlowController.RunState.MANUAL_PAUSE
	await process_frame
	assert(controller.handle_primary_click(platform.get_cell_canvas_center(5)))
	assert(controller.is_feedback_error())
	flow.state = GameFlowController.RunState.RUNNING
	await process_frame

	assert(controller.handle_primary_click(platform.get_cell_canvas_center(4)))
	await process_frame
	panel.get_demolish_button().pressed.emit()
	assert(not grid.has_buildable(turret_id))
	assert(not panel.visible)

	assert(controller.handle_primary_click(platform.get_cell_canvas_center(medical_cell)))
	await process_frame
	panel.get_demolish_button().pressed.emit()
	assert(not grid.has_buildable(medical_id))
	assert(not medical.has_station())
	assert(not panel.visible)

	print("Buildable placement UI scenarios passed")
	quit()


func _stabilize_world(game: Node) -> void:
	for path: NodePath in [
		NodePath("World/BoardingSpawnDirector"),
		NodePath("World/FlyingEnemySpawnDirector"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
	]:
		if game.has_node(path):
			var system: Node = game.get_node(path)
			system.set_process(false)
			system.set_physics_process(false)
