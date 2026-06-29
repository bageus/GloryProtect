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
	var inventory: BuildableInventory = game.get_node("BuildableInventory")
	var grid: BuildableGrid = game.get_node("World/BuildableGrid")
	var medical: MedicalStationSystem = game.get_node("World/MedicalStationSystem")
	var platform: PlatformController = game.get_node("World/Platform")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var roles: CrewRoleManager = game.get_node("World/Platform/CrewRoleManager")

	await _wait_for_assignment_runtime(roles, 0, 30)
	game_flow.state = GameFlowController.RunState.RUNNING
	medical.balance.heal_interval = 0.12
	medical.balance.heal_range = 1000.0

	var allowed_cells: Array[int] = grid.balance.get_medical_cell_indices()
	var first_cell: int = 3
	var second_cell: int = 12
	assert(allowed_cells.has(first_cell))
	assert(allowed_cells.has(second_cell))
	assert(grid.balance.get_medical_footprint_cells(first_cell) == [first_cell])
	assert(grid.balance.get_medical_footprint_cells(second_cell) == [second_cell])
	assert(not grid.balance.is_reserved_cell(6))
	assert(not grid.balance.is_reserved_cell(7))
	assert(not roles.is_role_station_available(CrewRole.Id.MEDIC))
	assert(grid.place(BuildableType.Id.MEDICAL_STATION, first_cell) == -1)
	assert(inventory.unlock(BuildableType.Id.MEDICAL_STATION) == 1)

	var medical_id: int = grid.place(
		BuildableType.Id.MEDICAL_STATION,
		first_cell
	)
	assert(medical_id >= 0)
	await process_frame
	assert(medical.has_station())
	assert(roles.is_role_station_available(CrewRole.Id.MEDIC))
	assert(grid.get_buildable_id_at_cell(first_cell) == medical_id)
	assert(grid.get_buildable_id_at_cell(first_cell + 1) == -1)
	assert(grid.move(medical_id, second_cell))
	await process_frame
	assert(grid.get_buildable_id_at_cell(first_cell) == -1)
	assert(grid.get_buildable_id_at_cell(second_cell) == medical_id)

	var medical_snapshot: BuildableSnapshot = grid.get_snapshot(medical_id)
	assert(medical_snapshot.cell_index == second_cell)
	assert(is_equal_approx(
		medical_snapshot.local_x,
		platform.get_cell_local_x(second_cell)
	))

	roles.request_assignment(0, CrewRole.Id.MEDIC)
	await _wait_for_role(roles, 0, CrewRole.Id.MEDIC, 240)
	var first_target: Defender = crew.get_defender(1)
	var second_target: Defender = crew.get_defender(2)
	first_target.health.set_health(1)
	second_target.health.set_health(2)

	await _wait_for_healing_target(medical, 1, 120)
	assert(medical.is_healing_cycle_active(0))
	var remaining_before_pause: float = medical.get_heal_remaining()
	game_flow.begin_card_selection()
	await _wait_physics_frames(5)
	assert(is_equal_approx(medical.get_heal_remaining(), remaining_before_pause))
	game_flow.finish_card_selection()

	await _wait_for_health(first_target, 2, 120)
	await _wait_for_healing_target(medical, 2, 120)

	roles.request_assignment(0, CrewRole.Id.FREE_FIGHTER)
	var pending: CrewAssignmentRuntime = roles.get_assignment(0)
	assert(pending.current_role == CrewRole.Id.MEDIC)
	assert(pending.state == CrewAssignmentRuntime.State.WAITING_FOR_ACTION)
	await _wait_for_role(roles, 0, CrewRole.Id.FREE_FIGHTER, 180)
	assert(second_target.health.current_health == 3)

	roles.request_assignment(0, CrewRole.Id.MEDIC)
	await _wait_for_role(roles, 0, CrewRole.Id.MEDIC, 240)
	first_target.health.set_health(1)
	await _wait_for_healing_target(medical, 1, 120)
	assert(grid.demolish(medical_id))
	await process_frame
	assert(not medical.has_station())
	assert(medical.is_healing_cycle_active(0))
	assert(roles.is_role_station_available(CrewRole.Id.MEDIC))
	await _wait_for_role(roles, 0, CrewRole.Id.FREE_FIGHTER, 120)
	assert(not medical.is_healing_cycle_active(0))
	assert(not roles.is_role_station_available(CrewRole.Id.MEDIC))
	assert(first_target.health.current_health == 2)
	assert(inventory.is_unlocked(BuildableType.Id.MEDICAL_STATION))
	assert(grid.get_buildable_id_at_cell(second_cell) == -1)
	assert(grid.place(BuildableType.Id.MEDICAL_STATION, 7) >= 0)

	print("Single-cell medical station placement scenarios passed")
	quit()


func _wait_for_assignment_runtime(
	roles: CrewRoleManager,
	defender_id: int,
	max_frames: int
) -> void:
	for _frame: int in range(max_frames):
		if roles.get_assignment(defender_id) != null:
			return
		await process_frame
	push_error("Crew role manager did not initialize assignments")
	quit(1)


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
	assert(false, "Defender did not reach requested role")


func _wait_for_healing_target(
	medical: MedicalStationSystem,
	target_id: int,
	max_frames: int
) -> void:
	for _frame: int in range(max_frames):
		if (
			medical.is_healing_cycle_active(medical.get_medic_id())
			and medical.get_target_id() == target_id
		):
			return
		await physics_frame
	assert(false, "Medical station did not select expected target")


func _wait_for_health(
	defender: Defender,
	expected_health: int,
	max_frames: int
) -> void:
	for _frame: int in range(max_frames):
		if defender.health.current_health == expected_health:
			return
		await physics_frame
	assert(false, "Defender health did not reach expected value")


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await physics_frame
