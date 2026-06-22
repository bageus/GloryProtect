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

	var medical: MedicalStationSystem = game.get_node("World/MedicalStationSystem")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	assert(medical.apply_upgrade_effect(_flag_effect(
		MedicUpgradeRuntime.PROTECTIVE
	)))

	var primary: Defender = crew.get_defender(0)
	primary.health.set_health(primary.health.max_health - 1)
	primary.health.heal(1)
	medical.segment_restored.emit(1, primary.defender_id, 1)
	assert(primary.health.current_health == primary.health.max_health)
	assert(primary.durability.get_temporary_armor() == 1)
	assert(primary.durability.has_next_hit_guard())

	primary.health.apply_damage(1, &"test_guard")
	assert(primary.health.current_health == primary.health.max_health)
	assert(primary.durability.get_temporary_armor() == 1)
	assert(not primary.durability.has_next_hit_guard())
	primary.health.apply_damage(1, &"test_armor")
	assert(primary.health.current_health == primary.health.max_health)
	assert(primary.durability.get_temporary_armor() == 0)

	assert(medical.apply_upgrade_effect(_flag_effect(
		&"medic_protective_chain"
	)))
	var secondary: Defender = crew.get_defender(1)
	var third: Defender = crew.get_defender(2)
	primary.health.set_health(1)
	secondary.health.set_health(1)
	third.health.set_health(2)
	primary.health.heal(1)
	medical.segment_restored.emit(2, primary.defender_id, 1)
	assert(primary.health.current_health == 2)
	assert(primary.durability.get_temporary_armor() == 1)
	assert(secondary.health.current_health == 2)
	assert(secondary.durability.get_temporary_armor() == 1)
	assert(third.health.current_health == 2)

	print("Medic protective healing scenarios passed")
	quit()


func _flag_effect(target_id: StringName) -> UpgradeEffectDefinition:
	var effect := UpgradeEffectDefinition.new()
	effect.effect_type = UpgradeEffectDefinition.EffectType.DOMAIN_FLAG
	effect.target_id = target_id
	return effect
