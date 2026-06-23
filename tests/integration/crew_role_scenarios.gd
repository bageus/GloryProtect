extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var game_flow := game.get_node("GameFlowController") as GameFlowController
	var roles := game.get_node("World/Platform/CrewRoleManager") as CrewRoleManager
	var crew := game.get_node("World/Platform/CrewManager") as CrewManager
	var steering := game.get_node("SteeringInputProvider") as SteeringInputProvider
	var anchors := game.get_node("World/AnchorSystem") as AnchorSystem
	var platform := game.get_node("World/Platform") as PlatformController
	var wind := game.get_node("WindSystem") as WindSystem

	game_flow.state = GameFlowController.RunState.RUNNING
	wind.balance.level_forces = PackedFloat32Array([0.0, 0.0, 0.0])
	wind.balance.fluctuation_force = 0.0
	wind.set_debug_state(1, 1)
	platform.position.x = 0.0
	platform.horizontal_velocity = 0.0

	assert(roles.get_assignment(0).current_role == CrewRole.Id.DRIVER)
	assert(roles.get_assignment(1).current_role == CrewRole.Id.LEFT_ANCHOR)
	assert(roles.get_assignment(2).current_role == CrewRole.Id.RIGHT_ANCHOR)
	assert(steering.driver_available)

	Input.action_press(&"ui_left")
	roles.request_assignment(0, CrewRole.Id.FREE_FIGHTER)
	await process_frame
	assert(steering.driver_available)
	assert(
		roles.get_assignment(0).state
		== CrewAssignmentRuntime.State.WAITING_FOR_ACTION
	)

	Input.action_release(&"ui_left")
	await process_frame
	assert(not steering.driver_available)
	assert(
		roles.get_assignment(0).state == CrewAssignmentRuntime.State.MOVING
		or roles.get_assignment(0).state == CrewAssignmentRuntime.State.ACTIVE
	)

	await _wait_until_assignment_active(roles, 0)
	assert(roles.get_assignment(0).current_role == CrewRole.Id.FREE_FIGHTER)
	assert(
		roles.get_role_owner(CrewRole.Id.DRIVER) == -1,
		"Driver station remained reserved after releasing defender 0"
	)
	assert(
		roles.get_assignment(1).state == CrewAssignmentRuntime.State.ACTIVE,
		"Defender 1 was not active before requesting the driver role"
	)

	roles.request_assignment(1, CrewRole.Id.DRIVER)
	await process_frame
	assert(
		roles.get_assignment(1).target_role == CrewRole.Id.DRIVER,
		"Driver assignment request was rejected"
	)
	assert(not steering.driver_available)

	await _wait_until_assignment_active(roles, 1)
	assert(roles.get_assignment(1).current_role == CrewRole.Id.DRIVER)
	assert(steering.driver_available)
	assert(
		is_equal_approx(
			crew.get_defender(1).position.x,
			roles.get_role_target_x(CrewRole.Id.DRIVER, 1)
		)
	)

	platform.position.x = 0.0
	platform.horizontal_velocity = 0.0
	anchors.toggle_anchor(2)
	await process_frame
	assert(anchors.is_operator_busy(AnchorRuntime.Side.RIGHT))

	roles.request_assignment(2, CrewRole.Id.FREE_FIGHTER)
	await process_frame
	assert(
		roles.get_assignment(2).state
		== CrewAssignmentRuntime.State.WAITING_FOR_ACTION
	)
	assert(anchors.is_operator_assigned(AnchorRuntime.Side.RIGHT))

	await _wait_until_assignment_active(roles, 2, 400)
	assert(roles.get_assignment(2).current_role == CrewRole.Id.FREE_FIGHTER)
	assert(not anchors.is_operator_assigned(AnchorRuntime.Side.RIGHT))

	for defender in crew.get_all_defenders():
		defender.health.set_health(0)
	await process_frame
	assert(game_flow.state == GameFlowController.RunState.GAME_OVER)
	assert(game_flow.game_over_reason == &"all_defenders_dead")

	print("Crew role scenarios passed")
	quit()


func _wait_until_assignment_active(
	roles: CrewRoleManager,
	defender_id: int,
	max_frames: int = 300
) -> void:
	for _frame in range(max_frames):
		var assignment := roles.get_assignment(defender_id)
		if assignment.state == CrewAssignmentRuntime.State.ACTIVE:
			return
		await process_frame
	assert(false, "Defender did not reach the requested role in time")
