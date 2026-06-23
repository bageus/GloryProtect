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
	var first_old_instance_id: int = first_old.get_instance_id()
	var second_old_instance_id: int = second_old.get_instance_id()
	first_old.health.set_health(0)
	await _wait_physics_frames(10)
	second_old.health.set_health(0)

	assert(replacements.is_replacement_pending(1))
	assert(replacements.is_replacement_pending(2))
	assert(replacements.get_pending_count() == 2)

	var first_new: Defender = await _wait_for_replacement(
		crew,
		1,
		first_old_instance_id,
		120
	)
	assert(first_new != null)
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

	var second_new: Defender = await _wait_for_replacement(
		crew,
		2,
		second_old_instance_id,
		120
	)
	assert(second_new != null)
	assert(second_new.health.is_alive())
	assert(not replacements.is_replacement_pending(2))
	assert(replacements.get_pending_count() == 0)

	var second_assignment: CrewAssignmentRuntime = roles.get_assignment(2)
	assert(second_assignment.state == CrewAssignmentRuntime.State.ACTIVE)
	assert(second_assignment.current_role == CrewRole.Id.FREE_FIGHTER)
	assert(crew.get_living_count() == 3)

	print("Crew replacement scenarios passed")
	quit()


func _wait_for_replacement(
	crew: CrewManager,
	defender_id: int,
	old_instance_id: int,
	max_frames: int
) -> Defender:
	for _frame: int in range(max_frames):
		var current: Defender = crew.get_defender(defender_id)
		if (
			current != null
			and current.get_instance_id() != old_instance_id
			and current.health.is_alive()
		):
			return current
		await physics_frame
	return null


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await physics_frame
