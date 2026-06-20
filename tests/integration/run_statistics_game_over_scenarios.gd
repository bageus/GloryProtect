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
	var difficulty: RunDifficulty = game.get_node("RunDifficulty")
	var statistics: RunStatistics = game.get_node("RunStatistics")
	var rewards: BoardingRewardController = game.get_node(
		"World/BoardingRewardController"
	)
	var economy: RunEconomy = game.get_node("RunEconomy")
	var panel: Control = game.get_node("CanvasLayer/GameOverPanel")

	game_flow.state = GameFlowController.RunState.RUNNING
	difficulty.set_debug_elapsed_seconds(125.7)
	economy.add_coins(3, &"test_statistics")
	rewards.reward_granted.emit(1, 1, &"combat")
	rewards.reward_granted.emit(2, 1, &"anchor_path_closed")
	assert(statistics.get_physical_kills() == 2)
	assert(is_equal_approx(statistics.get_current_survival_seconds(), 125.7))
	assert(not panel.visible)

	game_flow.end_run(&"shield_section_destroyed")
	await process_frame
	assert(game_flow.state == GameFlowController.RunState.GAME_OVER)
	assert(statistics.has_final_snapshot())
	var snapshot: RunStatisticsSnapshot = statistics.get_final_snapshot()
	assert(is_equal_approx(snapshot.survival_seconds, 125.7))
	assert(snapshot.physical_kills == 2)
	assert(snapshot.remaining_coins == 3)
	assert(snapshot.purchased_upgrades == 0)
	assert(snapshot.end_reason == &"shield_section_destroyed")
	assert(panel.visible)
	assert(
		game.get_node("CanvasLayer/GameOverPanel/Panel/Margin/VBox/TimeLabel").text
		== "Время выживания: 02:05"
	)

	rewards.reward_granted.emit(3, 1, &"combat")
	assert(statistics.get_physical_kills() == 2)

	game_flow.start_run()
	await process_frame
	assert(not statistics.has_final_snapshot())
	assert(statistics.get_physical_kills() == 0)
	assert(not panel.visible)

	print("Run statistics and game over scenarios passed")
	quit()
