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

	panel.get_medical_button().pressed.emit()
	var medical_cell: int = grid.balance.get_medical_cell_indices()[0]
	var medical_canvas := platform.get_cell_canvas_center(medical_cell)
	controller.handle_pointer_motion(medical_canvas)
	assert(controller.get_cell_unavailability_reason(medical_cell) == &"")
	assert(controller.handle_primary_click(medical_canvas))
	var medical_id := grid.get_buildable_id_by_type(BuildableType.Id.MEDICAL_STATION)
	assert(medical_id >= 0)
	assert(medical.has_station())
	assert(grid.get_buildable_id_at_cell(6) == medical_id)
	assert(grid.get_buildable_id_at_cell(7) == medical_id)

	panel.get_move_button().pressed.emit()
	assert(controller.handle_primary_click(platform.get_cell_canvas_center(2)))
	assert(grid.get_snapshot(medical_id).cell_index == medical_cell)
	controller.cancel_current_action()

	panel.get_turret_button().pressed.emit()
	assert(controller.handle_primary_click(platform.get_cell_canvas_center(3)))
	var turret_id: int = grid.get_buildable_ids_by_type(BuildableType.Id.TURRET)[0]
	assert(turrets.has_turret(turret_id))
	panel.get_move_button().pressed.emit()
	assert(controller.handle_primary_click(platform.get_cell_canvas_center(4)))
	assert(grid.get_snapshot(turret_id).cell_index == 4)
	assert(is_equal_approx(
		roles.get_role_target_x(CrewRole.Id.TURRET, 0, turret_id),
		platform.get_cell_local_x(4)
	))

	flow.state = GameFlowController.RunState.MANUAL_PAUSE
	await process_frame
	assert(not controller.begin_placement(BuildableType.Id.TURRET))
	flow.state = GameFlowController.RunState.RUNNING
	await process_frame

	controller.select_buildable(turret_id)
	panel.get_demolish_button().pressed.emit()
	assert(not grid.has_buildable(turret_id))
	controller.select_buildable(medical_id)
	panel.get_demolish_button().pressed.emit()
	assert(not grid.has_buildable(medical_id))
	assert(not medical.has_station())

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
