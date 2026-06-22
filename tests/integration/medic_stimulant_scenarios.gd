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
	var controller: MedicStimulantController = game.get_node(
		"World/MedicStimulantController"
	)
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	controller.set_physics_process(false)
	assert(medical.apply_upgrade_effect(_flag_effect(
		MedicUpgradeRuntime.STIMULANT
	)))

	var target: Defender = crew.get_defender(0)
	var base_cooldown: float = target.melee.get_cooldown_duration()
	var base_move_speed: float = target.movement.move_speed
	assert(is_equal_approx(target.get_temporary_attack_speed_multiplier(), 1.0))
	medical.segment_restored.emit(1, target.defender_id, 1)
	assert(controller.is_active(target.defender_id))
	assert(is_equal_approx(controller.get_remaining(target.defender_id), 5.0))
	assert(is_equal_approx(target.get_temporary_attack_speed_multiplier(), 1.15))
	assert(is_equal_approx(
		target.melee.get_cooldown_duration(),
		base_cooldown / target.get_temporary_attack_speed_multiplier()
	))
	assert(is_equal_approx(target.movement.move_speed, base_move_speed * 1.15))

	flow.toggle_manual_pause()
	controller.call("_physics_process", 3.0)
	assert(is_equal_approx(controller.get_remaining(target.defender_id), 5.0))
	flow.toggle_manual_pause()

	flow.begin_card_selection()
	controller.call("_physics_process", 2.0)
	assert(is_equal_approx(controller.get_remaining(target.defender_id), 5.0))
	flow.finish_card_selection()

	controller.call("_physics_process", 4.9)
	assert(controller.is_active(target.defender_id))
	controller.call("_physics_process", 0.1)
	assert(not controller.is_active(target.defender_id))
	assert(is_equal_approx(target.get_temporary_attack_speed_multiplier(), 1.0))
	assert(is_equal_approx(target.melee.get_cooldown_duration(), base_cooldown))
	assert(is_equal_approx(target.movement.move_speed, base_move_speed))

	print("Medic stimulant scenarios passed")
	quit()


func _flag_effect(target_id: StringName) -> UpgradeEffectDefinition:
	var effect := UpgradeEffectDefinition.new()
	effect.effect_type = UpgradeEffectDefinition.EffectType.DOMAIN_FLAG
	effect.target_id = target_id
	return effect
