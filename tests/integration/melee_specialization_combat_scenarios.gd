extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	await _test_duelist_double_attack_is_sequential()
	await _test_assault_hits_forward_group_and_rear_enemy()
	await _test_heavy_fifth_hit_bashes_two_enemies()
	print("Melee specialization combat scenarios passed")
	quit()


func _test_duelist_double_attack_is_sequential() -> void:
	var game: Node2D = await _create_stable_game()
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var director: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	assert(crew.apply_melee_flag(&"melee_specialization_duelist"))
	assert(crew.apply_melee_flag(&"melee_duelist_double_attack"))
	var defender: Defender = crew.get_defender(0)
	defender.teleport_to(0.0)
	var target: BoardingEnemy = _spawn_boarded_enemy(director, 30.0)
	target.health.configure(5)

	assert(bool(defender.combat.call("_try_start_attack", target)))
	defender.melee.tick(0.4)
	assert(target.health.current_health == 4)
	assert(defender.melee.is_attacking())
	assert(defender.combat.get_completed_hit_count() == 1)

	defender.melee.tick(0.4)
	assert(target.health.current_health == 3)
	assert(not defender.melee.is_attacking())
	assert(defender.combat.get_completed_hit_count() == 2)

	game.queue_free()
	await process_frame


func _test_assault_hits_forward_group_and_rear_enemy() -> void:
	var game: Node2D = await _create_stable_game()
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var director: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	assert(crew.apply_melee_flag(&"melee_specialization_assault"))
	assert(crew.apply_melee_flag(&"melee_assault_back_attack"))
	var defender: Defender = crew.get_defender(0)
	defender.teleport_to(0.0)

	var primary: BoardingEnemy = _spawn_boarded_enemy(director, 30.0)
	var behind_one: BoardingEnemy = _spawn_boarded_enemy(director, 62.0)
	var behind_two: BoardingEnemy = _spawn_boarded_enemy(director, 94.0)
	var behind_three: BoardingEnemy = _spawn_boarded_enemy(director, 126.0)
	var behind_four: BoardingEnemy = _spawn_boarded_enemy(director, 158.0)
	var rear: BoardingEnemy = _spawn_boarded_enemy(director, -30.0)

	assert(bool(defender.combat.call("_try_start_attack", primary)))
	defender.melee.tick(0.4)
	assert(primary.health.current_health == 1)
	assert(behind_one.health.current_health == 2)
	assert(behind_two.health.current_health == 2)
	assert(behind_three.health.current_health == 2)
	assert(behind_four.health.current_health == 3)
	assert(rear.health.current_health == 2)

	game.queue_free()
	await process_frame


func _test_heavy_fifth_hit_bashes_two_enemies() -> void:
	var game: Node2D = await _create_stable_game()
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var director: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	assert(crew.apply_melee_flag(&"melee_specialization_heavy"))
	assert(crew.apply_melee_flag(&"melee_heavy_shield_bash"))
	var defender: Defender = crew.get_defender(0)
	defender.teleport_to(0.0)
	assert(defender.blocks_enemy_jump())

	var primary: BoardingEnemy = _spawn_boarded_enemy(director, 30.0)
	var behind_one: BoardingEnemy = _spawn_boarded_enemy(director, 62.0)
	var behind_two: BoardingEnemy = _spawn_boarded_enemy(director, 94.0)
	var behind_three: BoardingEnemy = _spawn_boarded_enemy(director, 126.0)
	primary.health.configure(20)
	var behind_one_start: float = behind_one.controller.get_platform_local_x()
	var behind_two_start: float = behind_two.controller.get_platform_local_x()

	for _hit: int in range(5):
		assert(bool(defender.combat.call("_try_start_attack", primary)))
		defender.melee.tick(0.4)
		defender.melee.tick(defender.melee.get_cooldown_duration() + 0.01)

	var completed_hits: int = defender.combat.get_completed_hit_count()
	print("heavy bash hits=%d health=[%d,%d,%d] start=[%.2f,%.2f] end=[%.2f,%.2f,%.2f]" % [
		completed_hits,
		behind_one.health.current_health,
		behind_two.health.current_health,
		behind_three.health.current_health,
		behind_one_start,
		behind_two_start,
		behind_one.controller.get_platform_local_x(),
		behind_two.controller.get_platform_local_x(),
		behind_three.controller.get_platform_local_x(),
	])
	assert(completed_hits == 5, "Expected 5 completed hits, got %d" % completed_hits)
	assert(behind_one.health.current_health == 2)
	assert(behind_two.health.current_health == 2)
	assert(behind_three.health.current_health == 3)
	assert(behind_one.controller.get_platform_local_x() > behind_one_start)
	assert(behind_two.controller.get_platform_local_x() > behind_two_start)

	game.queue_free()
	await process_frame


func _create_stable_game() -> Node2D:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	flow.state = GameFlowController.RunState.RUNNING
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
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	for defender: Defender in crew.get_all_defenders():
		defender.combat.set_physics_process(false)
	return game


func _spawn_boarded_enemy(
	director: BoardingSpawnDirector,
	local_x: float
) -> BoardingEnemy:
	var enemy: BoardingEnemy = director.spawn_debug_archetype(&"brute", 1)
	assert(enemy != null)
	enemy.force_board_at(local_x)
	enemy.controller.set_physics_process(false)
	return enemy
