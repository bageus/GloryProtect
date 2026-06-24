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

	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var roles: CrewRoleManager = game.get_node(
		"World/Platform/CrewRoleManager"
	)
	await _wait_for_assignment(roles, 0)
	var rejected_reason: StringName = &""
	roles.assignment_rejected.connect(func(
		_defender_id: int,
		_role_id: int,
		reason: StringName
	) -> void:
		rejected_reason = reason
	)

	roles.request_assignment(0, CrewRole.Id.SHOOTER)
	assert(rejected_reason == &"role_unavailable")
	assert(roles.get_assignment(0).current_role != CrewRole.Id.SHOOTER)

	assert(crew.apply_shooter_flag(&"shooter_role_unlocked"))
	assert(crew.is_shooter_role_unlocked())
	rejected_reason = &""
	roles.request_assignment(0, CrewRole.Id.SHOOTER)
	await _wait_for_active_role(roles, 0, CrewRole.Id.SHOOTER)
	assert(rejected_reason == &"")

	var defender: Defender = crew.get_defender(0)
	defender.ranged.phase = RangedAttackComponent.Phase.WINDUP
	roles.request_assignment(0, CrewRole.Id.FREE_FIGHTER)
	assert(
		roles.get_assignment(0).state
		== CrewAssignmentRuntime.State.WAITING_FOR_ACTION
	)
	defender.ranged.phase = RangedAttackComponent.Phase.COOLDOWN
	roles._process(0.0)
	assert(
		roles.get_assignment(0).state
		!= CrewAssignmentRuntime.State.WAITING_FOR_ACTION
	)
	await _wait_for_active_role(roles, 0, CrewRole.Id.FREE_FIGHTER)

	roles.request_assignment(0, CrewRole.Id.SHOOTER)
	await _wait_for_active_role(roles, 0, CrewRole.Id.SHOOTER)
	crew.reset_run_modifiers()
	assert(not crew.is_shooter_role_unlocked())
	var reset_assignment: CrewAssignmentRuntime = roles.get_assignment(0)
	assert(reset_assignment.current_role == CrewRole.Id.FREE_FIGHTER)
	assert(reset_assignment.target_role == CrewRole.Id.FREE_FIGHTER)
	assert(reset_assignment.state == CrewAssignmentRuntime.State.ACTIVE)

	print("Shooter role unlock scenario passed")
	quit()


func _wait_for_assignment(roles: CrewRoleManager, defender_id: int) -> void:
	for _frame: int in range(60):
		if roles.get_assignment(defender_id) != null:
			return
		await process_frame
	assert(false, "Timed out waiting for crew assignment initialization")


func _wait_for_active_role(
	roles: CrewRoleManager,
	defender_id: int,
	role_id: int
) -> void:
	for _frame: int in range(180):
		var assignment := roles.get_assignment(defender_id)
		if (
			assignment != null
			and assignment.current_role == role_id
			and assignment.state == CrewAssignmentRuntime.State.ACTIVE
		):
			return
		await physics_frame
	assert(false, "Timed out waiting for role activation")
