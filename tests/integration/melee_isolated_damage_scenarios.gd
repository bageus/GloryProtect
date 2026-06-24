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
	var registry: BoardingEnemyRegistry = game.get_node("World/BoardingEnemyRegistry")
	director.set_process(false)
	director.set_physics_process(false)
	assert(crew.apply_melee_flag(&"melee_specialization_duelist"))
	assert(crew.apply_melee_flag(&"melee_duelist_isolated_damage"))
	var defender: Defender = crew.get_defender(0)
	defender.teleport_to(0.0)
	for crew_member: Defender in crew.get_all_defenders():
		crew_member.combat.set_physics_process(false)

	var primary: BoardingEnemy = _spawn_enemy(director, 30.0)
	print("isolated flag=%s defender_damage=%d primary=(%.2f, %.2f) health=%d" % [
		str(crew.get_melee_upgrades().duelist_isolated_damage),
		defender.melee.get_damage(),
		primary.global_position.x,
		primary.global_position.y,
		primary.health.current_health,
	])
	var boarded: Array[BoardingEnemy] = registry.get_boarded_enemies()
	print("isolated boarded_count=%d" % boarded.size())
	for enemy: BoardingEnemy in boarded:
		print("isolated enemy id=%d pos=(%.2f, %.2f) distance_to_primary=%.2f alive=%s" % [
			enemy.enemy_id,
			enemy.global_position.x,
			enemy.global_position.y,
			primary.global_position.distance_to(enemy.global_position),
			str(enemy.health.is_alive()),
		])
	assert(bool(defender.combat.call("_try_start_attack", primary)))
	defender.melee.tick(0.4)
	print("isolated primary_health_after_first=%d" % primary.health.current_health)
	assert(primary.health.current_health == 1)
	defender.melee.tick(defender.melee.get_cooldown_duration() + 0.01)

	primary.health.set_health(3)
	var neighbor: BoardingEnemy = _spawn_enemy(director, 58.0)
	assert(
		primary.global_position.distance_to(neighbor.global_position)
		<= director.balance.defender_attack_range
	)
	assert(bool(defender.combat.call("_try_start_attack", primary)))
	defender.melee.tick(0.4)
	assert(primary.health.current_health == 2)
	assert(neighbor.health.current_health == 3)

	print("Melee isolated damage scenarios passed")
	quit()


func _spawn_enemy(
	director: BoardingSpawnDirector,
	local_x: float
) -> BoardingEnemy:
	var enemy: BoardingEnemy = director.spawn_debug_archetype(&"brute", 1)
	assert(enemy != null)
	enemy.force_board_at(local_x)
	enemy.controller.set_physics_process(false)
	return enemy
