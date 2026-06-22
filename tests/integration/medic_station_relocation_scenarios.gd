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
	_stabilize_world(game)

	var inventory: BuildableInventory = game.get_node("BuildableInventory")
	var grid: BuildableGrid = game.get_node("World/BuildableGrid")
	var medical: MedicalStationSystem = game.get_node("World/MedicalStationSystem")
	var roles: CrewRoleManager = game.get_node("World/Platform/CrewRoleManager")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	medical.set_physics_process(false)

	assert(inventory.unlock(BuildableType.Id.MEDICAL_STATION, 1) == 1)
	var station_id: int = grid.place(BuildableType.Id.MEDICAL_STATION, 11)
	assert(station_id >= 0)
	await process_frame
	var medic: Defender = crew.get_defender(1)
	var target: Defender = crew.get_defender(0)
	roles.request_assignment(medic.defender_id, CrewRole.Id.MEDIC)
	await _wait_for_role(roles, medic.defender_id, CrewRole.Id.MEDIC)
	medic.teleport_to(target.position.x)
	target.health.set_health(1)

	medical.call("_physics_process", 0.0)
	assert(medical.is_healing_cycle_active(medic.defender_id))
	assert(is_equal_approx(medical.get_heal_remaining(), 5.0))
	assert(grid.move(station_id, 12))
	var assignment: CrewAssignmentRuntime = roles.get_assignment(medic.defender_id)
	assert(assignment.state == CrewAssignmentRuntime.State.WAITING_FOR_ACTION)
	assert(medical.is_healing_cycle_active(medic.defender_id))
	assert(is_equal_approx(medical.get_heal_remaining(), 5.0))

	medical.call("_physics_process", 5.0)
	assert(target.health.current_health == 2)
	assert(not medical.is_healing_cycle_active(medic.defender_id))
	await _wait_for_role(roles, medic.defender_id, CrewRole.Id.MEDIC)
	assert(is_equal_approx(
		medic.position.x,
		grid.get_cell_local_x(12)
	))

	medic.teleport_to(target.position.x)
	target.health.set_health(1)
	medical.call("_physics_process", 0.0)
	assert(medical.is_healing_cycle_active(medic.defender_id))
	assert(grid.demolish(station_id))
	assert(not medical.has_station())
	assert(not medical.is_healing_cycle_active(medic.defender_id))
	assert(target.health.current_health == 1)
	await process_frame
	assignment = roles.get_assignment(medic.defender_id)
	assert(assignment.state == CrewAssignmentRuntime.State.ACTIVE)
	assert(assignment.current_role == CrewRole.Id.FREE_FIGHTER)

	print("Medic station relocation scenarios passed")
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
			and assignment.state == CrewAssignmentRuntime.State.ACTIVE
			and assignment.current_role == role_id
		):
			return
		await process_frame
	assert(false, "Defender did not reach requested role")


func _stabilize_world(game: Node) -> void:
	var paths: Array[NodePath] = [
		NodePath("World/BoardingSpawnDirector"),
		NodePath("World/FlyingEnemySpawnDirector"),
		NodePath("World/StrategicWaveSystem"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
	]
	for path: NodePath in paths:
		if not game.has_node(path):
			continue
		var system: Node = game.get_node(path)
		system.set_process(false)
		system.set_physics_process(false)
