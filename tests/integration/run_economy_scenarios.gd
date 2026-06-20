extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var game_flow: GameFlowController = game.get_node("GameFlowController")
	var economy: RunEconomy = game.get_node("RunEconomy")
	var spawn: BoardingSpawnDirector = game.get_node(
		"World/BoardingSpawnDirector"
	)
	var reward: int = economy.balance.boarding_enemy_base_reward

	assert(economy.get_coins() == economy.balance.starting_coins)
	assert(reward > 0)

	var combat_enemy: BoardingEnemy = spawn.spawn_debug_on_platform(120.0)
	combat_enemy.kill(&"combat")
	await process_frame
	assert(economy.get_coins() == reward)

	combat_enemy.kill(&"combat")
	await process_frame
	assert(economy.get_coins() == reward)

	var anchor_enemy: BoardingEnemy = spawn.spawn_debug_on_platform(140.0)
	anchor_enemy.kill(&"anchor_path_closed")
	await process_frame
	assert(economy.get_coins() == reward * 2)

	var cleanup_enemy: BoardingEnemy = spawn.spawn_debug_on_platform(160.0)
	cleanup_enemy.kill(&"test_cleanup")
	await process_frame
	assert(economy.get_coins() == reward * 2)

	var strategic_enemy: BoardingEnemy = spawn.spawn_debug_on_platform(180.0)
	strategic_enemy.kill(&"strategic_collision")
	await process_frame
	assert(economy.get_coins() == reward * 2)

	assert(economy.can_afford(reward))
	assert(economy.spend_coins(reward, &"test_purchase"))
	assert(economy.get_coins() == reward)
	assert(not economy.spend_coins(reward + 1, &"test_purchase"))
	assert(economy.get_coins() == reward)

	economy.add_coins(0, &"test_invalid")
	economy.add_coins(-5, &"test_invalid")
	assert(economy.get_coins() == reward)

	game_flow.end_run(&"test_reset")
	game_flow.start_run()
	await process_frame
	assert(economy.get_coins() == economy.balance.starting_coins)

	print("Run economy scenarios passed")
	quit()
