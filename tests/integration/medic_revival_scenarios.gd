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

	var medical: MedicalStationSystem = game.get_node("World/MedicalStationSystem")
	var revival: MedicRevivalController = game.get_node(
		"World/MedicRevivalController"
	)
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var roles: CrewRoleManager = game.get_node("World/Platform/CrewRoleManager")
	var replacements: CrewReplacementController = game.get_node(
		"CrewReplacementController"
	)
	revival.set_physics_process(false)
	replacements.set_physics_process(false)
	assert(medical.apply_upgrade_effect(_flag_effect(
		MedicUpgradeRuntime.STIMULANT
	)))
	assert(medical.apply_upgrade_effect(_flag_effect(
		&"medic_stimulant_revival"
	)))

	var ordinary_id: int = 0
	crew.get_defender(ordinary_id).health.set_health(0)
	assert(flow.state == GameFlowController.RunState.RUNNING)
	assert(revival.is_revival_scheduled(ordinary_id))
	assert(is_equal_approx(revival.get_cooldown_remaining(), 60.0))
	await process_frame
	var ordinary_replacement: Defender = crew.get_defender(ordinary_id)
	assert(ordinary_replacement != null and ordinary_replacement.health.is_alive())
	assert(not replacements.is_replacement_pending(ordinary_id))
	var ordinary_assignment: CrewAssignmentRuntime = roles.get_assignment(ordinary_id)
	assert(ordinary_assignment.state == CrewAssignmentRuntime.State.ACTIVE)
	assert(ordinary_assignment.current_role == CrewRole.Id.FREE_FIGHTER)
	assert(crew.get_living_count() == 3)

	flow.toggle_manual_pause()
	revival.call("_physics_process", 30.0)
	assert(is_equal_approx(revival.get_cooldown_remaining(), 60.0))
	flow.toggle_manual_pause()

	ordinary_replacement.health.set_health(0)
	crew.get_defender(1).health.set_health(0)
	assert(crew.get_living_count() == 1)
	assert(not revival.is_revival_scheduled())
	revival.call("_physics_process", 60.0)
	assert(is_equal_approx(revival.get_cooldown_remaining(), 0.0))

	var last_id: int = 2
	crew.get_defender(last_id).health.set_health(0)
	assert(flow.state == GameFlowController.RunState.RUNNING)
	assert(revival.is_revival_scheduled(last_id))
	assert(is_equal_approx(revival.get_cooldown_remaining(), 60.0))
	await process_frame

	var last_replacement: Defender = crew.get_defender(last_id)
	assert(last_replacement != null and last_replacement.health.is_alive())
	assert(crew.get_living_count() == 1)
	assert(not replacements.is_replacement_pending(last_id))
	var last_assignment: CrewAssignmentRuntime = roles.get_assignment(last_id)
	assert(last_assignment.state == CrewAssignmentRuntime.State.ACTIVE)
	assert(last_assignment.current_role == CrewRole.Id.FREE_FIGHTER)
	assert(flow.state == GameFlowController.RunState.RUNNING)

	last_replacement.health.set_health(0)
	assert(flow.state == GameFlowController.RunState.GAME_OVER)
	assert(crew.get_living_count() == 0)

	print("Medic revival scenarios passed")
	quit()


func _flag_effect(target_id: StringName) -> UpgradeEffectDefinition:
	var effect := UpgradeEffectDefinition.new()
	effect.effect_type = UpgradeEffectDefinition.EffectType.DOMAIN_FLAG
	effect.target_id = target_id
	return effect


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
