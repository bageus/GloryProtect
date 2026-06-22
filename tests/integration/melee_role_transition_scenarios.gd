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
	flow.state = GameFlowController.RunState.RUNNING

	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var roles: CrewRoleManager = game.get_node("World/Platform/CrewRoleManager")
	var director: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	_stabilize_world(game, director, crew)
	assert(crew.apply_melee_flag(&"melee_specialization_duelist"))
	assert(crew.apply_melee_flag(&"melee_duelist_double_attack"))

	var defender: Defender = crew.get_defender(1)
	var assignment: CrewAssignmentRuntime = roles.get_assignment(defender.defender_id)
	assert(assignment.current_role == CrewRole.Id.LEFT_ANCHOR)
	assert(assignment.state == CrewAssignmentRuntime.State.ACTIVE)

	var target: BoardingEnemy = director.spawn_debug_archetype(&"brute", 1)
	assert(target != null)
	target.health.configure(2)
	target.force_board_at(defender.position.x)
	target.controller.set_physics_process(false)
	assert(bool(defender.combat.call("_try_start_attack", target)))
	assert(defender.melee.is_attacking())

	roles.request_assignment(defender.defender_id, CrewRole.Id.FREE_FIGHTER)
	assert(assignment.state == CrewAssignmentRuntime.State.WAITING_FOR_ACTION)
	assert(assignment.current_role == CrewRole.Id.LEFT_ANCHOR)

	defender.melee.tick(10.0)
	assert(target.health.current_health == 1)
	assert(defender.melee.is_attacking())
	roles.call("_process", 0.0)
	assert(assignment.state == CrewAssignmentRuntime.State.WAITING_FOR_ACTION)
	assert(assignment.current_role == CrewRole.Id.LEFT_ANCHOR)

	defender.melee.tick(10.0)
	assert(target.health.current_health == 0)
	assert(defender.combat.get_completed_hit_count() == 2)
	roles.call("_process", 0.0)
	assert(assignment.state in [
		CrewAssignmentRuntime.State.MOVING,
		CrewAssignmentRuntime.State.ACTIVE,
	])

	for _frame: int in range(240):
		if (
			assignment.state == CrewAssignmentRuntime.State.ACTIVE
			and assignment.current_role == CrewRole.Id.FREE_FIGHTER
		):
			break
		await process_frame
	assert(assignment.state == CrewAssignmentRuntime.State.ACTIVE)
	assert(assignment.current_role == CrewRole.Id.FREE_FIGHTER)

	print("Melee role transition scenarios passed")
	quit()


func _stabilize_world(
	game: Node,
	director: BoardingSpawnDirector,
	crew: CrewManager
) -> void:
	director.set_process(false)
	director.set_physics_process(false)
	var node_paths: Array[NodePath] = [
		NodePath("World/StrategicWaveSystem"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
	]
	for path: NodePath in node_paths:
		var system: Node = game.get_node(path)
		system.set_process(false)
		system.set_physics_process(false)
	for defender: Defender in crew.get_all_defenders():
		defender.combat.set_physics_process(false)
