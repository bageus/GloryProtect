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
	var roles := game.get_node(
		"World/Platform/CrewRoleManager"
	) as ShooterCrewRoleManagerPolished
	var replacements: CrewReplacementController = game.get_node(
		"CrewReplacementController"
	)
	var inventory: BuildableInventory = game.get_node("BuildableInventory")
	var grid: BuildableGrid = game.get_node("World/BuildableGrid")
	var panel := game.get_node(
		"CanvasLayer/PrototypeHUD/CrewCommandPanel"
	) as CrewCommandPanelPlacementPolished
	flow.state = GameFlowController.RunState.RUNNING
	_disable_spawners(game)

	for defender_id: int in range(3):
		roles.request_assignment(defender_id, CrewRole.Id.FREE_FIGHTER)
		await _wait_for_role(
			roles,
			defender_id,
			CrewRole.Id.FREE_FIGHTER
		)

	assert(crew.apply_shooter_flag(&"shooter_role_unlocked"))
	assert(crew.apply_shooter_flag(&"shooter_specialization_sniper"))
	roles.request_assignment(0, CrewRole.Id.SHOOTER)
	await _wait_for_role(roles, 0, CrewRole.Id.SHOOTER)
	await _wait_for_free_cell(panel, 0)
	assert(panel._get_available_free_defenders(-1).has(0))
	assert(roles.get_combat_role(0) == CrewRole.Id.SHOOTER)

	await _check_work_role(roles, 0, CrewRole.Id.DRIVER)
	await _check_work_role(roles, 0, CrewRole.Id.LEFT_ANCHOR)
	await _check_work_role(roles, 0, CrewRole.Id.RIGHT_ANCHOR)

	assert(inventory.unlock(BuildableType.Id.MEDICAL_STATION, 1) == 1)
	var medical_cell: int = grid.balance.get_medical_cell_indices()[0]
	assert(grid.place(BuildableType.Id.MEDICAL_STATION, medical_cell) >= 0)
	await process_frame
	assert(roles.is_role_station_available(CrewRole.Id.MEDIC))
	await _check_work_role(roles, 0, CrewRole.Id.MEDIC)

	assert(inventory.unlock(BuildableType.Id.TURRET, 1) == 1)
	var turret_id: int = grid.place(
		BuildableType.Id.TURRET,
		grid.balance.turret_cell_indices[0]
	)
	assert(turret_id >= 0)
	await process_frame
	assert(roles.is_role_station_available(CrewRole.Id.TURRET, turret_id))
	await _check_work_role(roles, 0, CrewRole.Id.TURRET, turret_id)

	roles.request_assignment(0, CrewRole.Id.DRIVER)
	await _wait_for_role(roles, 0, CrewRole.Id.DRIVER)
	var first_life: Defender = crew.get_defender(0)
	first_life.health.apply_damage(999, &"test", self)
	var first_replacement: Defender = replacements.complete_replacement_now(0)
	assert(first_replacement != null)
	await process_frame
	_assert_returning_to_driver(roles, 0)

	first_replacement.health.apply_damage(999, &"test", self)
	var second_replacement: Defender = replacements.complete_replacement_now(0)
	assert(second_replacement != null)
	await process_frame
	_assert_returning_to_driver(roles, 0)
	await _wait_for_role(roles, 0, CrewRole.Id.DRIVER)
	assert(roles.get_combat_role(0) == CrewRole.Id.SHOOTER)

	print("Stage 6.1 post assignment scenarios passed")
	quit()


func _check_work_role(
	roles: ShooterCrewRoleManagerPolished,
	defender_id: int,
	role_id: int,
	station_id: int = -1
) -> void:
	roles.request_assignment(defender_id, role_id, station_id)
	await _wait_for_role(roles, defender_id, role_id, station_id)
	assert(roles.get_combat_role(defender_id) == CrewRole.Id.SHOOTER)
	roles.request_assignment(defender_id, CrewRole.Id.SHOOTER)
	await _wait_for_role(roles, defender_id, CrewRole.Id.SHOOTER)
	assert(roles.get_combat_role(defender_id) == CrewRole.Id.SHOOTER)


func _assert_returning_to_driver(
	roles: ShooterCrewRoleManagerPolished,
	defender_id: int
) -> void:
	var assignment: CrewAssignmentRuntime = roles.get_assignment(defender_id)
	assert(assignment != null)
	assert(assignment.state == CrewAssignmentRuntime.State.MOVING)
	assert(assignment.target_role == CrewRole.Id.DRIVER)
	assert(assignment.combat_role == CrewRole.Id.SHOOTER)


func _wait_for_role(
	roles: CrewRoleManager,
	defender_id: int,
	role_id: int,
	station_id: int = -1
) -> void:
	for _frame: int in range(480):
		var assignment: CrewAssignmentRuntime = roles.get_assignment(defender_id)
		if (
			assignment != null
			and assignment.current_role == role_id
			and assignment.state == CrewAssignmentRuntime.State.ACTIVE
			and (
				station_id < 0
				or assignment.current_station_id == station_id
			)
		):
			return
		await physics_frame
	assert(false, "Defender did not reach requested role")


func _wait_for_free_cell(
	panel: CrewCommandPanelPlacementPolished,
	defender_id: int
) -> void:
	for _frame: int in range(120):
		if panel._free_cell_by_defender.has(defender_id):
			return
		await process_frame
	assert(false, "Defender did not receive a free cell")


func _disable_spawners(game: Node) -> void:
	var paths: Array[NodePath] = [
		NodePath("World/BoardingSpawnDirector"),
		NodePath("World/FlyingEnemySpawnDirector"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
	]
	for path: NodePath in paths:
		if not game.has_node(path):
			continue
		var node: Node = game.get_node(path)
		node.set_process(false)
		node.set_physics_process(false)
