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
	var medical_anchor: int = grid.balance.get_medical_cell_indices()[0]
	assert(grid.place(BuildableType.Id.MEDICAL_STATION, medical_anchor) >= 0)
	await process_frame
	assert(medical.apply_upgrade_effect(_flag_effect(
		MedicUpgradeRuntime.FIELD
	)))
	assert(medical.apply_upgrade_effect(_flag_effect(
		&"medic_field_emergency"
	)))

	var medic: Defender = crew.get_defender(1)
	var target: Defender = crew.get_defender(0)
	roles.request_assignment(medic.defender_id, CrewRole.Id.MEDIC)
	await _wait_for_role(roles, medic.defender_id, CrewRole.Id.MEDIC)
	medic.teleport_to(target.position.x)
	target.health.set_health(1)

	medical.call("_physics_process", 0.0)
	assert(medical.is_healing_cycle_active(medic.defender_id))
	assert(medical.get_target_id() == target.defender_id)
	assert(is_equal_approx(medical.get_heal_remaining(), 2.5))

	roles.request_assignment(medic.defender_id, CrewRole.Id.FREE_FIGHTER)
	var assignment: CrewAssignmentRuntime = roles.get_assignment(medic.defender_id)
	assert(assignment.state == CrewAssignmentRuntime.State.WAITING_FOR_ACTION)

	assert(medical.apply_upgrade_effect(_scalar_effect(
		&"medic_heal_speed_bonus_ratio",
		0.2
	)))
	assert(is_equal_approx(medical.get_current_heal_interval(), 5.0 / 1.2))
	assert(is_equal_approx(medical.get_heal_remaining(), 2.5))

	medical.call("_physics_process", 2.49)
	assert(target.health.current_health == 1)
	assert(assignment.state == CrewAssignmentRuntime.State.WAITING_FOR_ACTION)
	medical.call("_physics_process", 0.01)
	assert(target.health.current_health == 2)
	assert(not medical.is_healing_cycle_active(medic.defender_id))
	await process_frame
	assert(assignment.state in [
		CrewAssignmentRuntime.State.MOVING,
		CrewAssignmentRuntime.State.ACTIVE,
	])

	print("Medic emergency cycle scenarios passed")
	quit()


func _flag_effect(target_id: StringName) -> UpgradeEffectDefinition:
	var effect := UpgradeEffectDefinition.new()
	effect.effect_type = UpgradeEffectDefinition.EffectType.DOMAIN_FLAG
	effect.target_id = target_id
	return effect


func _scalar_effect(target_id: StringName, value: float) -> UpgradeEffectDefinition:
	var effect := UpgradeEffectDefinition.new()
	effect.effect_type = UpgradeEffectDefinition.EffectType.DOMAIN_SCALAR
	effect.target_id = target_id
	effect.scalar_value = value
	return effect


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
