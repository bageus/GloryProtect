extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var roles := game.get_node("World/Platform/CrewRoleManager") as CrewRoleManager
	var crew := game.get_node("World/Platform/CrewManager") as CrewManager
	var steering := game.get_node("SteeringInputProvider") as SteeringInputProvider

	assert(roles.get_assignment(0).current_role == CrewRole.Id.DRIVER)
	assert(roles.get_assignment(1).current_role == CrewRole.Id.LEFT_ANCHOR)
	assert(roles.get_assignment(2).current_role == CrewRole.Id.RIGHT_ANCHOR)
	assert(steering.driver_available)

	roles.request_assignment(0, CrewRole.Id.FREE_FIGHTER)
	await process_frame
	assert(not steering.driver_available)
	assert(
		roles.get_assignment(0).state == CrewAssignmentRuntime.State.MOVING
		or roles.get_assignment(0).state == CrewAssignmentRuntime.State.ACTIVE
	)

	await _wait_until_assignment_active(roles, 0)
	assert(roles.get_assignment(0).current_role == CrewRole.Id.FREE_FIGHTER)

	roles.request_assignment(1, CrewRole.Id.DRIVER)
	await process_frame
	assert(not steering.driver_available)

	await _wait_until_assignment_active(roles, 1)
	assert(roles.get_assignment(1).current_role == CrewRole.Id.DRIVER)
	assert(steering.driver_available)
	assert(crew.get_defender(1).position.x == 0.0)

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
