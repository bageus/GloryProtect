extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var game_flow: GameFlowController = game.get_node("GameFlowController")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var roles: CrewRoleManager = game.get_node(
		"World/Platform/CrewRoleManager"
	)
	var replacements: CrewReplacementController = game.get_node(
		"CrewReplacementController"
	)

	game_flow.state = GameFlowController.RunState.RUNNING
	crew.balance.replacement_delay_seconds = 0.30

	var first_old: Defender = crew.get_defender(1)
	var second_old: Defender = crew.get_defender(2)
	first_old.health.set_health(0)
	await _wait_physics_frames(10)
	second_old.health.set_health(0)

	assert(replacements.is_replacement_pending(1))
	assert(replacements.is_replacement_pending(2))
	assert(replacements.get_pending_count() == 2)

	await _wait_physics_frames(10)
	var first_new: Defender = crew.get_defender(1)
	assert(first_new != first_old)
	assert(first_new.health.is_alive())
	assert(
		is_equal_approx(
			first_new.position.x,
			crew.balance.replacement_door_local_x
		)
	)
	assert(not replacements.is_replacement_pending(1))
	assert(replacements.is_replacement_pending(2))

	var first_assignment: CrewAssignmentRuntime = roles.get_assignment(1)
	assert(first_assignment.state == CrewAssignmentRuntime.State.ACTIVE)
	assert(first_assignment.current_role == CrewRole.Id.FREE_FIGHTER)

	await _wait_physics_frames(10)
	var second_new: Defender = crew.get_defender(2)
	assert(second_new != second_old)
	assert(second_new.health.is_alive())
	assert(not replacements.is_replacement_pending(2))
	assert(replacements.get_pending_count() == 0)

	var second_assignment: CrewAssignmentRuntime = roles.get_assignment(2)
	assert(second_assignment.state == CrewAssignmentRuntime.State.ACTIVE)
	assert(second_assignment.current_role == CrewRole.Id.FREE_FIGHTER)
	assert(crew.get_living_count() == 3)

	print("Crew replacement scenarios passed")
	quit()


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await physics_frame
