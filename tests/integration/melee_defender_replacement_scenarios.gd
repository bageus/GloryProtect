extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	await process_frame
	await process_frame

	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	assert(crew.apply_melee_scalar(&"melee_health_bonus", 2.0))
	assert(crew.apply_melee_scalar(&"melee_armor_bonus", 1.0))
	assert(crew.apply_melee_flag(&"melee_specialization_assault"))
	assert(crew.apply_melee_flag(&"melee_assault_lethal_guard"))

	for defender: Defender in crew.get_all_defenders():
		_assert_upgraded_defender(defender)

	var original: Defender = crew.get_defender(0)
	original.health.apply_damage(2)
	assert(original.health.current_health == original.health.max_health - 1)
	var replacement: Defender = crew.replace_defender(0, 0.0)
	assert(replacement != null)
	_assert_upgraded_defender(replacement)
	assert(replacement.health.current_health == replacement.health.max_health)

	crew.reset_run_modifiers()
	assert(crew.get_melee_upgrades().specialization_id == &"")
	for defender: Defender in crew.get_all_defenders():
		assert(defender.health.max_health == crew.balance.defender_max_health)
		assert(defender.durability.get_max_armor() == 0)
		assert(not defender.durability.has_lethal_guard())

	print("Melee defender replacement scenarios passed")
	quit()


func _assert_upgraded_defender(defender: Defender) -> void:
	assert(defender.health.max_health == defender._balance.defender_max_health + 2)
	assert(defender.durability.get_max_armor() == 1)
	assert(defender.durability.has_lethal_guard())
