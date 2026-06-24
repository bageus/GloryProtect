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
	var role_modifiers: MedicRoleModifierController = game.get_node(
		"World/MedicRoleModifierController"
	)
	var director: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	medical.set_physics_process(false)

	var medic: Defender = crew.get_defender(1)
	var patient: Defender = crew.get_defender(0)
	for _frame: int in range(60):
		if roles.get_assignment(medic.defender_id) != null:
			break
		await process_frame
	assert(roles.get_assignment(medic.defender_id) != null)

	assert(inventory.unlock(BuildableType.Id.MEDICAL_STATION, 1) == 1)
	assert(grid.place(
		BuildableType.Id.MEDICAL_STATION,
		grid.balance.default_medical_cell
	) >= 0)
	await process_frame
	assert(roles.is_role_station_available(CrewRole.Id.MEDIC))
	assert(medical.apply_upgrade_effect(_flag_effect(
		MedicUpgradeRuntime.FIELD
	)))
	assert(medical.apply_upgrade_effect(_flag_effect(
		&"medic_field_combat"
	)))

	roles.request_assignment(medic.defender_id, CrewRole.Id.MEDIC)
	await _wait_for_role(roles, medic.defender_id, CrewRole.Id.MEDIC)
	assert(role_modifiers.get_active_medic_id() == medic.defender_id)
	for defender: Defender in crew.get_all_defenders():
		defender.combat.set_physics_process(false)
	medic.teleport_to(patient.position.x)
	patient.health.set_health(1)

	var enemy: BoardingEnemy = director.spawn_debug_archetype(&"brute", 1)
	assert(enemy != null)
	enemy.health.configure(5)
	enemy.force_board_at(medic.position.x)
	enemy.controller.set_physics_process(false)
	assert(bool(medic.combat.call("_try_start_attack", enemy)))
	assert(medic.melee.is_attacking())

	medical.call("_physics_process", 0.0)
	assert(not medical.is_healing_cycle_active(medic.defender_id))
	medic.melee.tick(0.4)
	assert(not medic.melee.is_attacking())
	assert(enemy.health.current_health == 3)

	medical.call("_physics_process", 0.0)
	assert(medical.is_healing_cycle_active(medic.defender_id))
	assert(medical.get_target_id() == patient.defender_id)
	assert(not medic.can_medic_role_use_melee())
	medic.combat.call("_physics_process", 0.0)
	assert(not medic.melee.is_attacking())
	assert(enemy.health.current_health == 3)

	roles.request_assignment(medic.defender_id, CrewRole.Id.FREE_FIGHTER)
	var assignment: CrewAssignmentRuntime = roles.get_assignment(medic.defender_id)
	assert(assignment.state == CrewAssignmentRuntime.State.WAITING_FOR_ACTION)
	medical.call("_physics_process", medical.get_heal_remaining())
	assert(patient.health.current_health == 2)
	assert(not medical.is_healing_cycle_active(medic.defender_id))
	assert(role_modifiers.get_active_medic_id() == -1)
	assert(not medic.can_medic_role_use_melee())
	medic.combat.call("_physics_process", 0.0)
	assert(not medic.melee.is_attacking())
	assert(enemy.health.current_health == 3)
	await physics_frame
	assert(assignment.state in [
		CrewAssignmentRuntime.State.MOVING,
		CrewAssignmentRuntime.State.ACTIVE,
	])
	await _wait_for_role(roles, medic.defender_id, CrewRole.Id.FREE_FIGHTER)

	print("Medic field action priority scenarios passed")
	quit()


func _flag_effect(target_id: StringName) -> UpgradeEffectDefinition:
	var effect := UpgradeEffectDefinition.new()
	effect.effect_type = UpgradeEffectDefinition.EffectType.DOMAIN_FLAG
	effect.target_id = target_id
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
		await physics_frame
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
