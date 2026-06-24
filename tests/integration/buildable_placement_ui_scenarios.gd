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
	var panel: BuildablePlacementPanel = game.get_node(
		"CanvasLayer/BuildablePlacementPanel"
	)
	var medical: MedicalStationSystem = game.get_node(
		"World/MedicalStationSystem"
	)
	var turrets: TurretSystem = game.get_node("World/TurretSystem")
	var roles: CrewRoleManager = game.get_node("World/Platform/CrewRoleManager")
	var buildable_debug: BuildableDebugInput = game.get_node("BuildableDebugInput")
	var turret_debug: TurretDebugInput = game.get_node("TurretDebugInput")

	assert(buildable_debug.process_mode == Node.PROCESS_MODE_DISABLED)
	assert(turret_debug.process_mode == Node.PROCESS_MODE_DISABLED)
	assert(controller.are_commands_enabled())

	inventory.unlock(BuildableType.Id.MEDICAL_STATION)
	inventory.unlock(BuildableType.Id.TURRET, 2)
	await process_frame

	panel.get_medical_button().pressed.emit()
	assert(controller.get_mode() == BuildablePlacementController.Mode.PLACE)
	assert(flow.state == GameFlowController.RunState.RUNNING)
	var medical_cell := 7
	var medical_canvas := platform.get_cell_canvas_center(medical_cell)
	controller.handle_pointer_motion(medical_canvas)
	assert(controller.get_hovered_cell_index() == medical_cell)
	assert(controller.get_cell_unavailability_reason(medical_cell) == &"")
	assert(controller.handle_primary_click(medical_canvas))
	var medical_id := grid.get_buildable_id_by_type(
		BuildableType.Id.MEDICAL_STATION
	)
	assert(medical_id >= 0)
	assert(medical.has_station())
	assert(flow.state == GameFlowController.RunState.RUNNING)

	panel.get_move_button().pressed.emit()
	assert(controller.get_mode() == BuildablePlacementController.Mode.MOVE)
	var moved_medical_cell := 2
	assert(controller.handle_primary_click(
		platform.get_cell_canvas_center(moved_medical_cell)
	))
	assert(grid.get_snapshot(medical_id).cell_index == moved_medical_cell)
	assert(is_equal_approx(
		medical.get_station_local_x(),
		platform.get_cell_local_x(moved_medical_cell)
	))
	assert(is_equal_approx(
		roles.get_role_target_x(CrewRole.Id.MEDIC),
		platform.get_cell_local_x(moved_medical_cell)
	))

	panel.get_turret_button().pressed.emit()
	assert(controller.get_mode() == BuildablePlacementController.Mode.PLACE)
	var invalid_turret_cell := 7
	controller.handle_pointer_motion(
		platform.get_cell_canvas_center(invalid_turret_cell)
	)
	assert(
		controller.get_cell_unavailability_reason(invalid_turret_cell)
		== BuildableGrid.REASON_CELL_NOT_ALLOWED
	)
	assert(panel.get_cell_feedback_text().contains("не предназначена"))

	var turret_cell := 3
	assert(controller.handle_primary_click(
		platform.get_cell_canvas_center(turret_cell)
	))
	var turret_ids := grid.get_buildable_ids_by_type(BuildableType.Id.TURRET)
	assert(turret_ids.size() == 1)
	var turret_id := turret_ids[0]
	assert(turrets.has_turret(turret_id))
	assert(controller.get_selected_turret_id() == turret_id)

	panel.get_move_button().pressed.emit()
	var moved_turret_cell := 4
	assert(controller.handle_primary_click(
		platform.get_cell_canvas_center(moved_turret_cell)
	))
	assert(grid.get_snapshot(turret_id).cell_index == moved_turret_cell)
	assert(is_equal_approx(
		roles.get_role_target_x(CrewRole.Id.TURRET, 0, turret_id),
		platform.get_cell_local_x(moved_turret_cell)
	))

	flow.state = GameFlowController.RunState.MANUAL_PAUSE
	await process_frame
	assert(panel.get_turret_button().disabled)
	var turret_count_before := grid.get_count_by_type(BuildableType.Id.TURRET)
	assert(not controller.begin_placement(BuildableType.Id.TURRET))
	assert(controller.handle_primary_click(platform.get_cell_canvas_center(5)))
	assert(grid.get_count_by_type(BuildableType.Id.TURRET) == turret_count_before)
	assert(controller.get_feedback_message().contains("паузы"))

	flow.state = GameFlowController.RunState.CARD_SELECTION
	await process_frame
	assert(not controller.begin_move_selected())
	assert(controller.get_feedback_message().contains("карточки"))

	flow.state = GameFlowController.RunState.RUNNING
	await process_frame
	controller.select_buildable(turret_id)
	panel.get_demolish_button().pressed.emit()
	assert(not grid.has_buildable(turret_id))
	assert(not turrets.has_turret(turret_id))
	assert(not roles.is_role_station_available(CrewRole.Id.TURRET, turret_id))

	controller.select_buildable(medical_id)
	panel.get_demolish_button().pressed.emit()
	assert(not grid.has_buildable(medical_id))
	assert(not medical.has_station())
	assert(not roles.is_role_station_available(CrewRole.Id.MEDIC))

	print("Buildable placement UI scenarios passed")
	quit()


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
