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
	var platform: PlatformController = game.get_node("World/Platform")
	var controller: BuildablePlacementController = game.get_node(
		"BuildablePlacementController"
	)
	var panel: BuildablePlacementPanel = game.get_node(
		"CanvasLayer/BuildablePlacementPanel"
	)
	var medical: MedicalStationSystem = game.get_node(
		"World/MedicalStationSystem"
	)

	inventory.unlock(BuildableType.Id.MEDICAL_STATION)
	inventory.unlock(BuildableType.Id.TURRET, 2)
	await process_frame
	assert(not panel.visible)
	assert(not controller.is_grid_preview_visible())

	var medical_cell: int = 3
	assert(grid.balance.is_medical_cell(medical_cell))
	assert(controller.handle_primary_click(
		platform.get_cell_canvas_center(medical_cell)
	))
	await process_frame
	assert(panel.visible)
	assert(panel.get_medical_button().visible)
	assert(panel.get_turret_button().visible)
	panel.get_medical_button().pressed.emit()
	await process_frame

	var medical_id: int = grid.get_buildable_id_by_type(
		BuildableType.Id.MEDICAL_STATION
	)
	assert(medical_id >= 0)
	assert(medical.has_station())
	assert(grid.get_buildable_id_at_cell(medical_cell) == medical_id)
	assert(grid.get_buildable_id_at_cell(medical_cell + 1) == -1)
	assert(not panel.visible)
	assert(controller.handle_primary_click(
		platform.get_cell_canvas_center(medical_cell)
	))
	await process_frame
	assert(controller.get_selected_buildable_id() == medical_id)
	assert(panel.get_demolish_button().visible)
	assert(panel.get_move_button().visible)
	panel.get_move_button().pressed.emit()
	assert(controller.is_grid_preview_visible())
	var moved_medical_cell: int = 12
	assert(controller.handle_primary_click(
		platform.get_cell_canvas_center(moved_medical_cell)
	))
	await process_frame
	assert(grid.get_snapshot(medical_id).cell_index == moved_medical_cell)
	assert(grid.get_buildable_id_at_cell(medical_cell) == -1)
	assert(grid.get_buildable_id_at_cell(moved_medical_cell) == medical_id)
	assert(not controller.is_grid_preview_visible())
	assert(not panel.visible)

	var turret_cell: int = 4
	assert(controller.handle_primary_click(
		platform.get_cell_canvas_center(turret_cell)
	))
	await process_frame
	assert(panel.visible)
	assert(panel.get_turret_button().visible)
	assert(not panel.get_medical_button().visible)
	panel.get_turret_button().pressed.emit()
	await process_frame

	var turret_ids: Array[int] = grid.get_buildable_ids_by_type(
		BuildableType.Id.TURRET
	)
	assert(turret_ids.size() == 1)
	var turret_id: int = turret_ids[0]
	assert(not panel.visible)
	assert(controller.handle_primary_click(
		platform.get_cell_canvas_center(turret_cell)
	))
	await process_frame
	assert(panel.get_move_button().visible)
	assert(panel.get_demolish_button().visible)
	panel.get_move_button().pressed.emit()
	assert(controller.is_grid_preview_visible())
	assert(controller.handle_primary_click(
		platform.get_cell_canvas_center(5)
	))
	await process_frame
	assert(grid.get_snapshot(turret_id).cell_index == 5)
	assert(not controller.is_grid_preview_visible())
	assert(not panel.visible)

	assert(controller.handle_primary_click(
		platform.get_cell_canvas_center(5)
	))
	await process_frame
	panel.get_demolish_button().pressed.emit()
	assert(not grid.has_buildable(turret_id))
	assert(not panel.visible)

	print("Buildable cell context scenarios passed")
	quit()


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
