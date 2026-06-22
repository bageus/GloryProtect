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

	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var upgrades: UpgradeSystem = game.get_node("UpgradeSystem")
	assert(crew.apply_melee_scalar(&"melee_damage_bonus", 1.0))
	assert(crew.apply_melee_scalar(&"melee_health_bonus", 1.0))
	assert(crew.apply_melee_scalar(&"melee_armor_bonus", 1.0))
	assert(crew.apply_melee_flag(&"melee_specialization_heavy"))
	var runtime: MeleeDefenderUpgradeRuntime = crew.get_melee_upgrades()
	var defender: Defender = crew.get_defender(0)
	assert(runtime.get_damage(1) == 2)
	assert(runtime.specialization_id == MeleeDefenderUpgradeRuntime.HEAVY)
	assert(defender.health.max_health == crew.balance.defender_max_health + 2)
	assert(defender.durability.get_max_armor() == 1)

	upgrades.reset_for_run()
	assert(runtime.get_damage(1) == 1)
	assert(runtime.get_max_health(crew.balance.defender_max_health) == crew.balance.defender_max_health)
	assert(runtime.specialization_id == &"")
	assert(runtime.armor_bonus == 0)
	for crew_member: Defender in crew.get_all_defenders():
		assert(crew_member.health.max_health == crew.balance.defender_max_health)
		assert(crew_member.health.current_health == crew.balance.defender_max_health)
		assert(crew_member.durability.get_max_armor() == 0)
		assert(not crew_member.durability.has_lethal_guard())

	print("Melee run reset scenarios passed")
	quit()
