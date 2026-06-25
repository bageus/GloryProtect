extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run_scenario")


func _run_scenario() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var flow: GameFlowController = game.get_node("GameFlowController")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var roles: CrewRoleManager = game.get_node(
		"World/Platform/CrewRoleManager"
	)
	var platform: PlatformController = game.get_node("World/Platform")
	var panel: CrewCommandPanelPlacementAware = game.get_node(
		"CanvasLayer/PrototypeHUD/CrewCommandPanel"
	)
	flow.state = GameFlowController.RunState.RUNNING

	roles.request_assignment(0, CrewRole.Id.FREE_FIGHTER)
	await _wait_for_role(roles, 0, CrewRole.Id.FREE_FIGHTER)
	panel._free_cell_by_defender[0] = 2
	crew.get_defender(0).teleport_to(platform.get_cell_local_x(2))

	assert(not panel.request_defender_type(0, CrewRole.Id.SHOOTER))
	assert(roles.get_assignment(0).current_role == CrewRole.Id.FREE_FIGHTER)
	assert(crew.apply_shooter_flag(&"shooter_role_unlocked"))
	assert(panel.request_defender_type(0, CrewRole.Id.SHOOTER))
	await _wait_for_role(roles, 0, CrewRole.Id.SHOOTER)
	await _wait_frames(3)
	assert(int(panel._free_cell_by_defender[0]) == 2)
	assert(is_equal_approx(
		crew.get_defender(0).position.x,
		platform.get_cell_local_x(2)
	))

	assert(panel.request_defender_type(0, CrewRole.Id.FREE_FIGHTER))
	await _wait_for_role(roles, 0, CrewRole.Id.FREE_FIGHTER)
	await _wait_frames(3)
	assert(int(panel._free_cell_by_defender[0]) == 2)
	assert(is_equal_approx(
		crew.get_defender(0).position.x,
		platform.get_cell_local_x(2)
	))

	print("Defender type selection scenarios passed")
	quit()


func _wait_for_role(
	roles: CrewRoleManager,
	defender_id: int,
	role_id: int
) -> void:
	for _frame: int in range(360):
		var assignment: CrewAssignmentRuntime = roles.get_assignment(defender_id)
		if (
			assignment != null
			and assignment.current_role == role_id
			and assignment.state == CrewAssignmentRuntime.State.ACTIVE
		):
			return
		await physics_frame
	assert(false, "Defender did not reach requested type")


func _wait_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await process_frame
