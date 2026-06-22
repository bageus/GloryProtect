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
	assert(inventory.unlock(BuildableType.Id.MEDICAL_STATION, 1) == 1)
	assert(grid.place(BuildableType.Id.MEDICAL_STATION, 11) >= 0)
	await process_frame

	var medic: Defender = crew.get_defender(1)
	roles.request_assignment(medic.defender_id, CrewRole.Id.MEDIC)
	await _wait_for_role(roles, medic.defender_id, CrewRole.Id.MEDIC)
	await process_frame
	for defender: Defender in crew.get_all_defenders():
		defender.combat.set_physics_process(false)

	var target: BoardingEnemy = director.spawn_debug_archetype(&"brute", 1)
	assert(target != null)
	target.health.configure(3)
	target.force_board_at(medic.position.x)
	target.controller.set_physics_process(false)

	medic.combat.call("_physics_process", 0.0)
	assert(not medic.melee.is_attacking())
	assert(target.health.current_health == 3)

	assert(medical.apply_upgrade_effect(_flag_effect(
		MedicUpgradeRuntime.FIELD
	)))
	await process_frame
	assert(is_equal_approx(
		medic.movement.move_speed,
		crew.get_current_movement_speed() * 1.15
	))
	assert(not medic.can_medic_role_use_melee())

	assert(medical.apply_upgrade_effect(_flag_effect(
		&"medic_field_combat"
	)))
	await process_frame
	assert(medic.can_medic_role_use_melee())
	assert(medic.melee.get_damage() == 2)
	medic.combat.call("_physics_process", 0.0)
	assert(medic.melee.is_attacking())
	medic.melee.tick(0.4)
	assert(target.health.current_health == 1)
	medic.melee.tick(medic.melee.get_cooldown_duration())

	medical.healing_started.emit(medic.defender_id, medic.defender_id)
	assert(not medic.can_medic_role_use_melee())
	medic.combat.call("_physics_process", 0.0)
	assert(not medic.melee.is_attacking())
	assert(target.health.current_health == 1)

	medical.healing_stopped.emit(medic.defender_id, medic.defender_id)
	assert(medic.can_medic_role_use_melee())
	medic.combat.call("_physics_process", 0.0)
	assert(medic.melee.is_attacking())
	roles.request_assignment(medic.defender_id, CrewRole.Id.FREE_FIGHTER)
	var assignment: CrewAssignmentRuntime = roles.get_assignment(medic.defender_id)
	assert(assignment.state == CrewAssignmentRuntime.State.WAITING_FOR_ACTION)
	await process_frame
	assert(role_modifiers.get_active_medic_id() == medic.defender_id)
	assert(medic.can_medic_role_use_melee())
	assert(medic.melee.get_damage() == 2)
	medic.melee.tick(0.4)
	assert(not target.health.is_alive())
	medic.melee.tick(medic.melee.get_cooldown_duration())

	await _wait_for_role(roles, medic.defender_id, CrewRole.Id.FREE_FIGHTER)
	await process_frame
	assert(role_modifiers.get_active_medic_id() == -1)
	assert(not medic.can_medic_role_use_melee())
	assert(is_equal_approx(
		medic.movement.move_speed,
		crew.get_current_movement_speed()
	))

	print("Medic field combat scenarios passed")
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
