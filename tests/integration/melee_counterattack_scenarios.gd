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

	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var director: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	director.set_process(false)
	director.set_physics_process(false)
	var node_paths: Array[NodePath] = [
		NodePath("World/StrategicWaveSystem"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
	]
	for path: NodePath in node_paths:
		var system: Node = game.get_node(path)
		system.set_process(false)
		system.set_physics_process(false)

	assert(crew.apply_melee_scalar(&"melee_armor_bonus", 1.0))
	assert(crew.apply_melee_flag(&"melee_specialization_duelist"))
	assert(crew.apply_melee_flag(&"melee_duelist_counterattack"))
	var defender: Defender = crew.get_defender(0)
	defender.teleport_to(0.0)
	defender.combat.set_physics_process(false)

	var attacker: BoardingEnemy = director.spawn_debug_archetype(&"basic", 1)
	var bystander: BoardingEnemy = director.spawn_debug_archetype(&"basic", 1)
	assert(attacker != null and bystander != null)
	attacker.force_board_at(30.0)
	bystander.force_board_at(-27.0)
	attacker.controller.set_physics_process(false)
	bystander.controller.set_physics_process(false)
	assert(
		defender.global_position.distance_to(attacker.global_position)
		<= director.balance.defender_attack_range
	)

	var health_before: int = defender.health.current_health
	assert(attacker.melee.try_start(defender.health))
	attacker.melee.tick(10.0)
	assert(defender.health.current_health == health_before)
	assert(defender.durability.get_current_armor() == 0)
	assert(attacker.health.current_health == 0)
	assert(bystander.health.current_health == 1)

	print("Melee counterattack scenarios passed")
	quit()
