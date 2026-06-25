extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame
	await process_frame

	var game_flow: GameFlowController = game.get_node("GameFlowController")
	var selection: CrewSelectionController = game.get_node("CrewDebugInput")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var roles: CrewRoleManager = game.get_node("World/Platform/CrewRoleManager")
	var replacements: CrewReplacementController = game.get_node("CrewReplacementController")
	var inventory: BuildableInventory = game.get_node("BuildableInventory")
	var grid: BuildableGrid = game.get_node("World/BuildableGrid")
	var panel: CrewCommandPanel = game.get_node("CanvasLayer/PrototypeHUD/CrewCommandPanel")

	game_flow.state = GameFlowController.RunState.RUNNING
	await process_frame

	assert(panel.get_defender_button_count() == 3)
	assert(panel.get_turret_button_count() == 0)
	assert(panel.are_commands_enabled())
	assert(selection.get_selected_defender_id() == 0)
	assert(crew.get_defender(0).visual.is_selected())
	assert(not crew.get_defender(1).visual.is_selected())

	assert(panel.select_defender(1))
	await process_frame
	assert(selection.get_selected_defender_id() == 1)
	assert(not crew.get_defender(0).visual.is_selected())
	assert(crew.get_defender(1).visual.is_selected())
	assert(panel.is_standard_role_enabled(CrewRole.Id.FREE_FIGHTER))

	panel.request_selected_role(CrewRole.Id.FREE_FIGHTER)
	await _wait_for_role(roles, 1, CrewRole.Id.FREE_FIGHTER, -1, 240)
	assert(panel.are_commands_enabled())

	assert(not panel.is_standard_role_enabled(CrewRole.Id.MEDIC))
	assert(inventory.unlock(BuildableType.Id.MEDICAL_STATION) == 1)
	var medical_anchor: int = grid.balance.get_medical_cell_indices()[0]
	var medical_id: int = grid.place(BuildableType.Id.MEDICAL_STATION, medical_anchor)
	assert(medical_id >= 0)
	await process_frame
	assert(panel.is_standard_role_enabled(CrewRole.Id.MEDIC))

	panel.request_selected_role(CrewRole.Id.MEDIC)
	await _wait_for_role(
		roles,
		1,
		CrewRole.Id.MEDIC,
		CrewRoleManager.DEFAULT_DYNAMIC_STATION_ID,
		300
	)

	assert(inventory.unlock(BuildableType.Id.TURRET) == 1)
	var turret_id: int = grid.place(BuildableType.Id.TURRET, 14)
	assert(turret_id >= 0)
	await process_frame
	assert(panel.get_turret_button_count() == 1)

	assert(panel.select_defender(2))
	panel.request_selected_role(CrewRole.Id.TURRET, turret_id)
	await _wait_for_role(roles, 2, CrewRole.Id.TURRET, turret_id, 300)
	assert(roles.get_role_owner(CrewRole.Id.TURRET, turret_id) == 2)

	assert(panel.select_defender(0))
	await process_frame
	assert(not panel.is_turret_role_enabled(turret_id))
	assert(panel.select_defender(2))
	await process_frame
	assert(panel.is_turret_role_enabled(turret_id))

	game_flow.begin_card_selection()
	await process_frame
	assert(not panel.are_commands_enabled())
	assert(not panel.visible)
	game_flow.finish_card_selection()
	await process_frame
	assert(panel.visible)
	assert(panel.are_commands_enabled())

	game_flow.toggle_manual_pause()
	await process_frame
	assert(panel.visible)
	assert(not panel.are_commands_enabled())
	game_flow.toggle_manual_pause()
	await process_frame
	assert(panel.visible)
	assert(panel.are_commands_enabled())

	assert(replacements.get_pending_count() == 0)
	print("Crew command panel scenarios passed")
	quit()


func _wait_for_role(
	roles: CrewRoleManager,
	defender_id: int,
	role_id: int,
	station_id: int,
	max_frames: int
) -> void:
	for _frame: int in range(max_frames):
		var assignment: CrewAssignmentRuntime = roles.get_assignment(defender_id)
		if (
			assignment != null
			and assignment.current_role == role_id
			and assignment.current_station_id == station_id
			and assignment.state == CrewAssignmentRuntime.State.ACTIVE
		):
			return
		await physics_frame
	assert(false, "Defender did not reach requested role")
