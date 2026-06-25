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
	var roles: CrewRoleManager = game.get_node("World/Platform/CrewRoleManager")
	var panel: CrewCommandPanelPlacementAware = game.get_node("CanvasLayer/PrototypeHUD/CrewCommandPanel")
	flow.state = GameFlowController.RunState.RUNNING
	roles.request_assignment(0, CrewRole.Id.FREE_FIGHTER)
	await _wait_role(roles, 0, CrewRole.Id.FREE_FIGHTER)
	await process_frame
	panel._selected_slot = 1
	panel._on_type_pressed(0, CrewRole.Id.SHOOTER)
	await process_frame
	assert(roles.get_assignment(0).current_role == CrewRole.Id.FREE_FIGHTER)
	assert(crew.apply_shooter_flag(&"shooter_role_unlocked"))
	panel._on_type_pressed(0, CrewRole.Id.SHOOTER)
	await _wait_role(roles, 0, CrewRole.Id.SHOOTER)
	panel._on_type_pressed(0, CrewRole.Id.FREE_FIGHTER)
	await _wait_role(roles, 0, CrewRole.Id.FREE_FIGHTER)
	print("Defender type selection scenarios passed")
	quit()

func _wait_role(roles: CrewRoleManager, defender_id: int, role_id: int) -> void:
	for _frame: int in range(360):
		var assignment: CrewAssignmentRuntime = roles.get_assignment(defender_id)
		if assignment != null and assignment.current_role == role_id and assignment.state == CrewAssignmentRuntime.State.ACTIVE:
			return
		await physics_frame
	assert(false, "Defender did not reach requested type")
