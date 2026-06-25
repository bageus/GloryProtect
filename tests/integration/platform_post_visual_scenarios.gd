extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var flow: GameFlowController = game.get_node("GameFlowController")
	var roles: CrewRoleManager = game.get_node("World/Platform/CrewRoleManager")
	var steering: SteeringInputProvider = game.get_node("World/Platform/SteeringInputProvider")
	var visual: PlatformVisualController = game.get_node(
		"World/Platform/PlatformVisualController"
	)
	var anchors: AnchorSystem = game.get_node("World/AnchorSystem")

	flow.state = GameFlowController.RunState.RUNNING
	await process_frame
	assert(steering.driver_available)
	assert(visual.driver_console_surface_offset.x == 80.0)
	assert(visual.platform_core_size == Vector2(92.0, 92.0))
	assert(visual.platform_core_offset == Vector2(0.0, 12.0))
	assert(anchors.is_operator_assigned(AnchorRuntime.Side.LEFT))
	assert(anchors.is_operator_assigned(AnchorRuntime.Side.RIGHT))

	roles.request_assignment(0, CrewRole.Id.FREE_FIGHTER)
	await _wait_for_role(roles, 0, CrewRole.Id.FREE_FIGHTER, 240)
	assert(not steering.driver_available)

	roles.request_assignment(1, CrewRole.Id.FREE_FIGHTER)
	await _wait_for_role(roles, 1, CrewRole.Id.FREE_FIGHTER, 240)
	assert(not anchors.is_operator_assigned(AnchorRuntime.Side.LEFT))

	roles.request_assignment(2, CrewRole.Id.FREE_FIGHTER)
	await _wait_for_role(roles, 2, CrewRole.Id.FREE_FIGHTER, 240)
	assert(not anchors.is_operator_assigned(AnchorRuntime.Side.RIGHT))

	print("Platform post visual scenarios passed")
	quit()


func _wait_for_role(
	roles: CrewRoleManager,
	defender_id: int,
	role_id: int,
	max_frames: int
) -> void:
	for _frame: int in range(max_frames):
		var assignment: CrewAssignmentRuntime = roles.get_assignment(defender_id)
		if (
			assignment != null
			and assignment.current_role == role_id
			and assignment.state == CrewAssignmentRuntime.State.ACTIVE
		):
			return
		await physics_frame
	assert(false, "Defender did not reach expected role")
