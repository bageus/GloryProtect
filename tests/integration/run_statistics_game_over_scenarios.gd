extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")
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
	_disable_spawners(game)

	var game_flow: GameFlowController = game.get_node("GameFlowController")
	var difficulty: RunDifficulty = game.get_node("RunDifficulty")
	var statistics: RunStatistics = game.get_node("RunStatistics")
	var rewards: BoardingRewardController = game.get_node(
		"World/BoardingRewardController"
	)
	var strategic: StrategicWaveSystem = game.get_node(
		"World/StrategicWaveSystem"
	)
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var economy: RunEconomy = game.get_node("RunEconomy")
	var panel: Control = game.get_node("CanvasLayer/GameOverPanel")
	var reason_label: Label = game.get_node(
		"CanvasLayer/GameOverPanel/Panel/Margin/VBox/ReasonLabel"
	)
	var new_record_label: Label = game.get_node(
		"CanvasLayer/GameOverPanel/Panel/Margin/VBox/NewRecordLabel"
	)
	var score_label: Label = game.get_node(
		"CanvasLayer/GameOverPanel/Panel/Margin/VBox/ScoreLabel"
	)
	var time_label: Label = game.get_node(
		"CanvasLayer/GameOverPanel/Panel/Margin/VBox/TimeLabel"
	)
	var kills_label: Label = game.get_node(
		"CanvasLayer/GameOverPanel/Panel/Margin/VBox/KillsLabel"
	)
	var losses_label: Label = game.get_node(
		"CanvasLayer/GameOverPanel/Panel/Margin/VBox/LossesLabel"
	)
	var session_label: Label = game.get_node(
		"CanvasLayer/GameOverPanel/Panel/Margin/VBox/SessionLabel"
	)
	var best_score_label: Label = game.get_node(
		"CanvasLayer/GameOverPanel/Panel/Margin/VBox/BestScoreLabel"
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
	strategic.strategic_enemy_impacted.emit(0, 1.0)
	strategic.strategic_enemy_impacted.emit(0, 1.0)
	strategic.strategic_enemy_impacted.emit(0, 1.0)
	strategic.emit_signal(&"strategic_rows_destroyed", 0, 2)
	crew.defender_died.emit(0)
	crew.defender_died.emit(0)
	assert(statistics.get_physical_kills() == 2)
	assert(statistics.get_strategic_kills() == 5)
	assert(statistics.get_total_kills() == 7)
	assert(statistics.get_defender_losses() == 2)
	assert(statistics.get_current_score() == 1320)
	assert(is_equal_approx(statistics.get_current_survival_seconds(), 125.7))
	assert(not panel.visible)

	game_flow.end_run(&"shield_section_destroyed")
	await process_frame
	assert(game_flow.state == GameFlowController.RunState.GAME_OVER)
	assert(statistics.has_final_snapshot())
	var snapshot: RunStatisticsSnapshot = statistics.get_final_snapshot()
	assert(is_equal_approx(snapshot.survival_seconds, 125.7))
	assert(snapshot.physical_kills == 2)
	assert(snapshot.strategic_kills == 5)
	assert(snapshot.total_kills == 7)
	assert(snapshot.defender_losses == 2)
	assert(snapshot.score == 1320)
	assert(snapshot.score_time_bonus == 0)
	assert(snapshot.remaining_coins == 3)
	assert(snapshot.purchased_upgrades == 0)
	assert(snapshot.end_reason == &"shield_section_destroyed")
	assert(statistics.was_final_score_new_record())
	assert(panel.visible)
	assert(new_record_label.visible)
	assert(reason_label.text == "СЕКЦИЯ ЩИТА РАЗРУШЕНА")
	assert(score_label.text == "Очки: 1320  |  бонус за время: +0")
	assert(time_label.text == "Время выживания: 02:05")
	assert(
		kills_label.text
		== "Уничтожено врагов: 7  |  физических: 2  |  стратегических: 5"
	)
	assert(losses_label.text == "Потери защитников: 2")
	assert(
		session_label.text
		== "Завершённые забеги — сессия: 1 | всего: 1"
	)
	assert(best_score_label.text == "Лучшие очки — сессия: 1320 | за всё время: 1320")
	assert(
		best_time_label.text
		== "Лучшее время — сессия: 02:05 | за всё время: 02:05"
	)
	assert(
		best_kills_label.text
		== "Лучшие физические убийства — сессия: 2 | за всё время: 2"
	)
	assert(statistics.get_session_completed_runs() == 1)
	assert(statistics.get_persistent_completed_runs() == 1)
	assert(statistics.get_session_best_score() == 1320)
	assert(statistics.get_persistent_best_score() == 1320)

	rewards.reward_granted.emit(3, 1, &"combat")
	assert(statistics.get_physical_kills() == 2)

	game_flow.start_run()
	await process_frame
	assert(not statistics.has_final_snapshot())
	assert(statistics.get_total_kills() == 0)
	assert(statistics.get_defender_losses() == 0)
	assert(statistics.get_persistent_completed_runs() == 1)
	assert(not panel.visible)

	game_flow.state = GameFlowController.RunState.RUNNING
	difficulty.set_debug_elapsed_seconds(60.0)
	rewards.reward_granted.emit(4, 1, &"combat")
	game_flow.end_run(&"all_defenders_dead")
	await process_frame
	assert(statistics.get_final_snapshot().score == 610)
	assert(not statistics.was_final_score_new_record())
	assert(not new_record_label.visible)
	assert(statistics.get_persistent_best_score() == 1320)

	game_flow.start_run()
	await process_frame
	game_flow.state = GameFlowController.RunState.RUNNING
	difficulty.set_debug_elapsed_seconds(130.0)
	rewards.reward_granted.emit(5, 1, &"combat")
	rewards.reward_granted.emit(6, 1, &"combat")
	crew.defender_died.emit(1)
	game_flow.end_run(&"all_defenders_dead")
	await process_frame
	assert(statistics.get_final_snapshot().score == 1320)
	assert(statistics.get_final_snapshot().defender_losses == 1)
	assert(statistics.was_final_score_new_record())
	assert(new_record_label.visible)
	assert(statistics.get_session_completed_runs() == 3)
	assert(statistics.get_persistent_completed_runs() == 3)
	assert(statistics.get_persistent_best_score() == 1320)
	assert(
		best_time_label.text
		== "Лучшее время — сессия: 02:10 | за всё время: 02:10"
	)

	persistent.reset_records_for_tests(true)
	print("Run statistics and game over scenarios passed")
	quit()


func _disable_spawners(game: Node) -> void:
	var paths: Array[NodePath] = [
		NodePath("World/BoardingSpawnDirector"),
		NodePath("World/FlyingEnemySpawnDirector"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
	]
	for path: NodePath in paths:
		if not game.has_node(path):
			continue
		var node: Node = game.get_node(path)
		node.set_process(false)
		node.set_physics_process(false)
