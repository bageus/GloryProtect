extends SceneTree

const APP_SCENE := preload("res://scenes/app/app_shell.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var shell := APP_SCENE.instantiate() as AppShell
	root.add_child(shell)
	await process_frame
	shell.start_new_game()
	await process_frame
	await process_frame
	await process_frame

	var game: Node2D = shell.get_active_game()
	assert(game != null)
	_disable_spawners(game)

	var flow: GameFlowController = game.get_node("GameFlowController")
	var inventory: BuildableInventory = game.get_node("BuildableInventory")
	var grid: BuildableGrid = game.get_node("World/BuildableGrid")
	var medical: MedicalStationSystem = game.get_node(
		"World/MedicalStationSystem"
	)
	var roles: CrewRoleManager = game.get_node(
		"World/Platform/CrewRoleManager"
	)
	var panel := game.get_node(
		"CanvasLayer/PrototypeHUD/CrewCommandPanel"
	) as CrewCommandPanelPlacementPolished
	assert(panel != null)

	flow.state = GameFlowController.RunState.RUNNING
	await _wait_for_assignment_runtime(roles, 0)
	assert(inventory.unlock(BuildableType.Id.MEDICAL_STATION, 1) == 1)
	var medical_cell: int = grid.balance.get_medical_cell_indices()[0]
	assert(grid.place(BuildableType.Id.MEDICAL_STATION, medical_cell) >= 0)
	await process_frame
	assert(medical.has_station())
	assert(roles.is_role_station_available(CrewRole.Id.MEDIC))

	# AppShell is the current scene and GameRoot is nested under GameHost. The
	# crew panel must still resolve the MedicalStationSystem from its own world.
	assert(panel._medical_system == medical)
	var medic_slot: int = _find_medic_slot(panel)
	assert(medic_slot >= 0)
	panel._on_assign_pressed(medic_slot, 0)

	var pending: CrewAssignmentRuntime = roles.get_assignment(0)
	assert(pending != null)
	assert(
		pending.current_role == CrewRole.Id.MEDIC
		or pending.target_role == CrewRole.Id.MEDIC
	)
	await _wait_for_role(roles, 0, CrewRole.Id.MEDIC)

	print("Medic assignment through AppShell scenario passed")
	quit()


func _find_medic_slot(panel: CrewCommandPanelPlacementPolished) -> int:
	for slot_index: int in range(panel._slot_specs.size()):
		var spec: Dictionary = panel._slot_specs[slot_index]
		if int(spec["kind"]) == CrewCommandPanel.SlotKind.MEDIC:
			return slot_index
	return -1


func _wait_for_assignment_runtime(
	roles: CrewRoleManager,
	defender_id: int,
	max_frames: int = 60
) -> void:
	for _frame: int in range(max_frames):
		if roles.get_assignment(defender_id) != null:
			return
		await process_frame
	assert(false, "Crew role manager did not initialize assignments")


func _wait_for_role(
	roles: CrewRoleManager,
	defender_id: int,
	role_id: int,
	max_frames: int = 480
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
	assert(false, "Defender did not reach the medical post")


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
