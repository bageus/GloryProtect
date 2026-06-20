class_name RunStatistics
extends Node

signal statistics_changed(survival_seconds: float, physical_kills: int)
signal run_finalized(snapshot: RunStatisticsSnapshot)
signal statistics_reset

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("RunDifficulty") var run_difficulty_path: NodePath
@export_node_path("BoardingRewardController") var reward_controller_path: NodePath
@export_node_path("RunEconomy") var run_economy_path: NodePath
@export_node_path("UpgradeSystem") var upgrade_system_path: NodePath

var _physical_kills: int = 0
var _final_snapshot: RunStatisticsSnapshot = null

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _difficulty: RunDifficulty = get_node(run_difficulty_path)
@onready var _rewards: BoardingRewardController = get_node(reward_controller_path)
@onready var _economy: RunEconomy = get_node(run_economy_path)
@onready var _upgrades: UpgradeSystem = get_node(upgrade_system_path)


func _ready() -> void:
	_game_flow.run_state_changed.connect(_on_run_state_changed)
	_game_flow.run_ended.connect(_on_run_ended)
	_rewards.reward_granted.connect(_on_reward_granted)
	reset_for_run()


func _process(_delta: float) -> void:
	if _game_flow.state != GameFlowController.RunState.RUNNING:
		return
	statistics_changed.emit(get_current_survival_seconds(), _physical_kills)


func get_current_survival_seconds() -> float:
	return _difficulty.get_elapsed_seconds()


func get_physical_kills() -> int:
	return _physical_kills


func get_final_snapshot() -> RunStatisticsSnapshot:
	return _final_snapshot


func has_final_snapshot() -> bool:
	return _final_snapshot != null


func get_session_completed_runs() -> int:
	return SessionRecordsStore.get_completed_runs()


func get_session_best_survival_seconds() -> float:
	return SessionRecordsStore.get_best_survival_seconds()


func get_session_best_physical_kills() -> int:
	return SessionRecordsStore.get_best_physical_kills()


func reset_for_run() -> void:
	_physical_kills = 0
	_final_snapshot = null
	statistics_reset.emit()
	statistics_changed.emit(0.0, 0)


func _on_reward_granted(
	_enemy_id: int,
	_amount: int,
	_reason: StringName
) -> void:
	if _game_flow.state == GameFlowController.RunState.GAME_OVER:
		return
	_physical_kills += 1
	statistics_changed.emit(get_current_survival_seconds(), _physical_kills)


func _on_run_ended(reason: StringName) -> void:
	_final_snapshot = RunStatisticsSnapshot.new(
		get_current_survival_seconds(),
		_physical_kills,
		_economy.get_coins(),
		_upgrades.get_completed_purchase_count(),
		reason
	)
	SessionRecordsStore.register_result(_final_snapshot)
	run_finalized.emit(_final_snapshot)


func _on_run_state_changed(previous_state: int, new_state: int) -> void:
	if new_state != GameFlowController.RunState.START_DELAY:
		return
	if previous_state == GameFlowController.RunState.MANUAL_PAUSE:
		return
	reset_for_run()
