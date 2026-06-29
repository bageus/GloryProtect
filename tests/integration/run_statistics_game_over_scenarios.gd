extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root.tscn")
const TEST_RECORDS_PATH := "user://run_statistics_game_over_records.json"


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	SessionRecordsStore.reset_records()
	var persistent := root.get_node(
		"PersistentRecordsRuntime"
	) as PersistentRecordsService
	assert(persistent != null)
	persistent.set_records_path_for_tests(TEST_RECORDS_PATH)
	persistent.reset_records_for_tests(true)

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
	var time_label: Label = game.get_node(
		"CanvasLayer/GameOverPanel/Panel/Margin/VBox/TimeLabel"
	)
	var session_label: Label = game.get_node(
		"CanvasLayer/GameOverPanel/Panel/Margin/VBox/SessionLabel"
	)
	var best_time_label: Label = game.get_node(
		"CanvasLayer/GameOverPanel/Panel/Margin/VBox/BestTimeLabel"
	)
	var best_kills_label: Label = game.get_node(
		"CanvasLayer/GameOverPanel/Panel/Margin/VBox/BestKillsLabel"
	)

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
	assert(time_label.text == "Время выживания: 02:05")
	assert(
		session_label.text
		== "Завершённые забеги — сессия: 1 | всего: 1"
	)
	assert(
		best_time_label.text
		== "Лучшее время — сессия: 02:05 | за всё время: 02:05"
	)
	assert(
		best_kills_label.text
		== "Лучшие убийства — сессия: 2 | за всё время: 2"
	)
	assert(statistics.get_session_completed_runs() == 1)
	assert(statistics.get_persistent_completed_runs() == 1)
	assert(is_equal_approx(
		statistics.get_session_best_survival_seconds(),
		125.7
	))
	assert(is_equal_approx(
		statistics.get_persistent_best_survival_seconds(),
		125.7
	))
	assert(statistics.get_session_best_physical_kills() == 2)
	assert(statistics.get_persistent_best_physical_kills() == 2)

	rewards.reward_granted.emit(3, 1, &"combat")
	assert(statistics.get_physical_kills() == 2)

	game_flow.start_run()
	await process_frame
	assert(not statistics.has_final_snapshot())
	assert(statistics.get_physical_kills() == 0)
	assert(statistics.get_persistent_completed_runs() == 1)
	assert(not panel.visible)

	game_flow.state = GameFlowController.RunState.RUNNING
	difficulty.set_debug_elapsed_seconds(60.0)
	rewards.reward_granted.emit(4, 1, &"combat")
	game_flow.end_run(&"all_defenders_dead")
	await process_frame
	assert(statistics.get_session_completed_runs() == 2)
	assert(statistics.get_persistent_completed_runs() == 2)
	assert(is_equal_approx(
		statistics.get_session_best_survival_seconds(),
		125.7
	))
	assert(is_equal_approx(
		statistics.get_persistent_best_survival_seconds(),
		125.7
	))
	assert(statistics.get_session_best_physical_kills() == 2)
	assert(statistics.get_persistent_best_physical_kills() == 2)
	assert(
		session_label.text
		== "Завершённые забеги — сессия: 2 | всего: 2"
	)
	assert(
		best_time_label.text
		== "Лучшее время — сессия: 02:05 | за всё время: 02:05"
	)
	assert(
		best_kills_label.text
		== "Лучшие убийства — сессия: 2 | за всё время: 2"
	)

	persistent.reset_records_for_tests(true)
	print("Run statistics and game over scenarios passed")
	quit()
