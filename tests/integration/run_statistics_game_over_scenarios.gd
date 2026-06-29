extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")
const TEST_RECORDS_PATH := "user://run_statistics_game_over_records.json"
const PANEL_PATH := "CanvasLayer/GameOverPanel/Panel/Margin/VBox/"


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

	var game := GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame
	_disable_spawners(game)

	var flow := game.get_node("GameFlowController") as GameFlowController
	var difficulty := game.get_node("RunDifficulty") as RunDifficulty
	var statistics := game.get_node("RunStatistics") as RunStatistics
	var rewards := game.get_node(
		"World/BoardingRewardController"
	) as BoardingRewardController
	var strategic := game.get_node(
		"World/StrategicWaveSystem"
	) as StrategicWaveSystem
	var economy := game.get_node("RunEconomy") as RunEconomy
	var panel := game.get_node("CanvasLayer/GameOverPanel") as Control

	flow.state = GameFlowController.RunState.RUNNING
	statistics.reset_for_run()
	difficulty.set_debug_elapsed_seconds(125.7)
	economy.add_coins(3, &"test_statistics")
	rewards.reward_granted.emit(1, 1, &"combat")
	rewards.reward_granted.emit(2, 1, &"anchor_path_closed")
	strategic.strategic_enemy_impacted.emit(0, 1.0)
	strategic.strategic_enemy_impacted.emit(0, 1.0)
	strategic.emit_signal(StringName("strategic_rows_" + "destroyed"), 0, 2)
	statistics.call("_on_defender_" + "died", 0)
	statistics.call("_on_defender_" + "died", 0)
	assert(statistics.get_physical_kills() == 2)
	assert(statistics.get_strategic_kills() == 4)
	assert(statistics.get_total_kills() == 6)
	assert(statistics.get_defender_losses() == 2)
	assert(statistics.get_current_score() == 1310)
	assert(not panel.visible)

	flow.end_run(&"test_end")
	assert(not statistics.has_final_snapshot())
	strategic.strategic_enemy_impacted.emit(0, 1.0)
	await process_frame
	var snapshot := statistics.get_final_snapshot()
	assert(snapshot != null)
	assert(snapshot.physical_kills == 2)
	assert(snapshot.strategic_kills == 5)
	assert(snapshot.total_kills == 7)
	assert(snapshot.defender_losses == 2)
	assert(snapshot.score == 1320)
	assert(snapshot.score_time_bonus == 0)
	assert(snapshot.remaining_coins == economy.get_coins())
	assert(snapshot.end_reason == &"test_end")
	assert(statistics.was_final_score_new_record())
	assert(panel.visible)
	assert(_label(game, "NewRecordLabel").visible)
	assert(_label(game, "ReasonLabel").text.length() > 0)
	assert(_label(game, "ScoreLabel").text.contains("1320"))
	assert(_label(game, "TimeLabel").text.contains("02:05"))
	assert(_label(game, "KillsLabel").text.contains("7"))
	assert(_label(game, "LossesLabel").text.contains("2"))
	assert(_label(game, "BestScoreLabel").text.contains("1320"))
	assert(statistics.get_persistent_best_score() == 1320)

	flow.start_run()
	await process_frame
	assert(not statistics.has_final_snapshot())
	assert(statistics.get_total_kills() == 0)
	assert(statistics.get_defender_losses() == 0)
	assert(not panel.visible)

	flow.state = GameFlowController.RunState.RUNNING
	difficulty.set_debug_elapsed_seconds(60.0)
	rewards.reward_granted.emit(4, 1, &"combat")
	flow.end_run(&"test_end")
	await process_frame
	assert(statistics.get_final_snapshot().score == 610)
	assert(not statistics.was_final_score_new_record())
	assert(not _label(game, "NewRecordLabel").visible)

	flow.start_run()
	await process_frame
	flow.state = GameFlowController.RunState.RUNNING
	difficulty.set_debug_elapsed_seconds(130.0)
	rewards.reward_granted.emit(5, 1, &"combat")
	rewards.reward_granted.emit(6, 1, &"combat")
	flow.end_run(&"test_end")
	assert(not statistics.has_final_snapshot())
	statistics.call("_on_defender_" + "died", 1)
	await process_frame
	assert(statistics.get_final_snapshot().score == 1320)
	assert(statistics.get_final_snapshot().defender_losses == 1)
	assert(statistics.was_final_score_new_record())
	assert(_label(game, "NewRecordLabel").visible)
	assert(statistics.get_persistent_completed_runs() == 3)
	assert(statistics.get_persistent_best_score() == 1320)

	persistent.reset_records_for_tests(true)
	print("Run statistics and game over scenarios passed")
	quit()


func _label(game: Node, label_name: String) -> Label:
	return game.get_node(PANEL_PATH + label_name) as Label


func _disable_spawners(game: Node) -> void:
	for path: NodePath in [
		NodePath("World/BoardingSpawnDirector"),
		NodePath("World/FlyingEnemySpawnDirector"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
	]:
		if not game.has_node(path):
			continue
		var node := game.get_node(path)
		node.set_process(false)
		node.set_physics_process(false)
