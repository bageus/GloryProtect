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
	var controller: MedicRoleModifierController = game.get_node(
		"World/MedicRoleModifierController"
	)

	assert(inventory.unlock(BuildableType.Id.MEDICAL_STATION, 1) == 1)
	assert(grid.place(BuildableType.Id.MEDICAL_STATION, 11) >= 0)
	await process_frame
	assert(medical.apply_upgrade_effect(_scalar_effect(
		&"medic_role_health_bonus",
		2.0
	)))
	assert(medical.apply_upgrade_effect(_scalar_effect(
		&"medic_role_armor_bonus",
		2.0
	)))
	await process_frame

	var first: Defender = crew.get_defender(1)
	roles.request_assignment(first.defender_id, CrewRole.Id.MEDIC)
	await _wait_for_role(roles, first.defender_id, CrewRole.Id.MEDIC)
	await process_frame
	assert(controller.get_active_medic_id() == first.defender_id)
	assert(first.health.max_health == crew.balance.defender_max_health + 2)
	assert(first.health.current_health == first.health.max_health)
	assert(first.durability.get_role_max_armor() == 2)
	assert(first.durability.get_role_current_armor() == 2)

	assert(crew.apply_melee_scalar(&"melee_health_bonus", 1.0))
	await process_frame
	var base_with_melee: int = crew.balance.defender_max_health + 1
	assert(first.health.max_health == base_with_melee + 2)
	assert(first.health.current_health == first.health.max_health)

	first.health.apply_damage(1, &"test")
	assert(first.health.current_health == first.health.max_health)
	assert(first.durability.get_role_current_armor() == 1)

	roles.request_assignment(first.defender_id, CrewRole.Id.FREE_FIGHTER)
	await _wait_for_role(roles, first.defender_id, CrewRole.Id.FREE_FIGHTER)
	await process_frame
	assert(first.health.max_health == base_with_melee)
	assert(first.durability.get_role_max_armor() == 0)
	assert(controller.get_stored_armor_segments() == 1)

	var second: Defender = crew.get_defender(2)
	roles.request_assignment(second.defender_id, CrewRole.Id.MEDIC)
	await _wait_for_role(roles, second.defender_id, CrewRole.Id.MEDIC)
	await process_frame
	assert(controller.get_active_medic_id() == second.defender_id)
	assert(second.health.max_health == base_with_melee + 2)
	assert(second.health.current_health == second.health.max_health)
	assert(second.durability.get_role_max_armor() == 2)
	assert(second.durability.get_role_current_armor() == 1)

	print("Medic role modifier scenarios passed")
	quit()


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
