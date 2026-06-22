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
	var roles: CrewRoleManager = game.get_node("World/Platform/CrewRoleManager")
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
	await process_frame
	await process_frame
	assert(rejected_reason == &"")
	assert(roles.get_assignment(0).current_role == CrewRole.Id.SHOOTER)

	crew.reset_run_modifiers()
	assert(not crew.is_shooter_role_unlocked())
	print("Shooter role unlock scenario passed")
	quit()
