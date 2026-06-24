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
	var stimulant: MedicStimulantController = game.get_node(
		"World/MedicStimulantController"
	)
	var revival: MedicRevivalController = game.get_node(
		"World/MedicRevivalController"
	)
	var replacements: CrewReplacementController = game.get_node(
		"CrewReplacementController"
	)
	stimulant.set_physics_process(false)
	revival.set_physics_process(false)

	var medic: Defender = crew.get_defender(1)
	var target: Defender = crew.get_defender(0)
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
	assert(medical.apply_upgrade_effect(_scalar_effect(
		&"medic_heal_amount_bonus",
		1.0
	)))
	assert(medical.apply_upgrade_effect(_scalar_effect(
		&"medic_role_health_bonus",
		2.0
	)))
	assert(medical.apply_upgrade_effect(_scalar_effect(
		&"medic_role_armor_bonus",
		2.0
	)))
	assert(medical.apply_upgrade_effect(_flag_effect(
		MedicUpgradeRuntime.STIMULANT
	)))
	assert(medical.apply_upgrade_effect(_flag_effect(
		&"medic_stimulant_revival"
	)))

	roles.request_assignment(medic.defender_id, CrewRole.Id.MEDIC)
	await _wait_for_role(roles, medic.defender_id, CrewRole.Id.MEDIC)
	await process_frame
	assert(role_modifiers.get_active_medic_id() == medic.defender_id)
	assert(medic.get_medic_role_health_bonus() == 2)
	assert(medic.durability.get_role_max_armor() == 2)

	target.health.set_health(target.health.max_health - 1)
	target.health.heal(1)
	medical.segment_restored.emit(medic.defender_id, target.defender_id, 1)
	assert(stimulant.is_active(target.defender_id))
	assert(target.durability.get_temporary_armor() == 0)
	assert(medical.get_current_heal_amount() == 2)
	assert(medical.upgrades.specialization_id == MedicUpgradeRuntime.STIMULANT)

	var last_id: int = 2
	crew.get_defender(0).health.set_health(0)
	crew.get_defender(1).health.set_health(0)
	crew.get_defender(last_id).health.set_health(0)
	assert(flow.state == GameFlowController.RunState.RUNNING)
	assert(revival.is_revival_scheduled())
	assert(revival.get_cooldown_remaining() > 0.0)
	await process_frame
	assert(crew.get_living_count() == 1)
	assert(replacements.get_pending_count() == 2)

	flow.start_run()
	assert(replacements.get_pending_count() == 0)
	assert(is_equal_approx(revival.get_cooldown_remaining(), 0.0))
	for defender: Defender in crew.get_all_defenders():
		assert(defender.get_medic_role_health_bonus() == 0)
		assert(defender.durability.get_role_max_armor() == 0)
		assert(defender.durability.get_temporary_armor() == 0)
		assert(not defender.durability.has_next_hit_guard())
		assert(is_equal_approx(
			defender.get_temporary_attack_speed_multiplier(),
			1.0
		))
	await process_frame
	await process_frame
	assert(flow.state in [
		GameFlowController.RunState.START_DELAY,
		GameFlowController.RunState.RUNNING,
	])
	assert(medical.get_current_heal_amount() == medical.balance.heal_amount)
	assert(medical.upgrades.specialization_id == &"")
	assert(not medical.upgrades.revival_enabled)
	assert(not stimulant.is_active(target.defender_id))
	assert(role_modifiers.get_active_medic_id() == -1)
	assert(role_modifiers.get_stored_health_segments() == 0)
	assert(role_modifiers.get_stored_armor_segments() == 0)
	assert(not medical.has_station())

	print("Medic run reset scenarios passed")
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
