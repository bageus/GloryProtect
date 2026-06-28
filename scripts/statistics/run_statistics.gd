class_name RunStatistics
extends Node

signal statistics_changed(survival_seconds: float, physical_kills: int)
signal run_finalized(snapshot: RunStatisticsSnapshot)
signal statistics_reset

const GENERAL_POOL_ID: StringName = &"general"

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("RunDifficulty") var run_difficulty_path: NodePath
@export_node_path("BoardingRewardController") var reward_controller_path: NodePath
@export_node_path("RunEconomy") var run_economy_path: NodePath
@export_node_path("UpgradeSystem") var upgrade_system_path: NodePath

var _physical_kills: int = 0
var _earned_coins: int = 0
var _spent_coins: int = 0
var _purchase_timeline: Array = []
var _offer_slot_counts: Dictionary[StringName, int] = {}
var _specialization_purchase_numbers: Array[int] = []
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
	_economy.coins_added.connect(_on_coins_added)
	_economy.coins_spent.connect(_on_coins_spent)
	_upgrades.offer_opened.connect(_on_offer_opened)
	_upgrades.card_selected_by_id.connect(_on_card_selected_by_id)
	reset_for_run()


func _process(_delta: float) -> void:
	if _game_flow.state != GameFlowController.RunState.RUNNING:
		return
	statistics_changed.emit(get_current_survival_seconds(), _physical_kills)


func get_current_survival_seconds() -> float:
	return _difficulty.get_elapsed_seconds()


func get_physical_kills() -> int:
	return _physical_kills


func get_earned_coins() -> int:
	return _earned_coins


func get_spent_coins() -> int:
	return _spent_coins


func get_coins_per_minute() -> float:
	var seconds: float = get_current_survival_seconds()
	if seconds <= 0.0:
		return 0.0
	return float(_earned_coins) * 60.0 / seconds


func get_purchase_timeline() -> Array:
	return _purchase_timeline.duplicate(true)


func get_offer_slot_counts() -> Dictionary[StringName, int]:
	return _offer_slot_counts.duplicate(true)


func get_specialization_purchase_numbers() -> Array[int]:
	return _specialization_purchase_numbers.duplicate()


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
	_earned_coins = 0
	_spent_coins = 0
	_purchase_timeline.clear()
	_offer_slot_counts.clear()
	_specialization_purchase_numbers.clear()
	_final_snapshot = null
	statistics_reset.emit()
	statistics_changed.emit(0.0, 0)


func _on_reward_granted(
	_enemy_id: int,
	_amount: int,
	_reason: StringName
) -> void:
	if _game_flow.state != GameFlowController.RunState.RUNNING:
		return
	_physical_kills += 1
	statistics_changed.emit(get_current_survival_seconds(), _physical_kills)


func _on_coins_added(amount: int, source: StringName) -> void:
	if source in [&"run_reset", &"upgrade_refund"]:
		return
	_earned_coins += maxi(0, amount)


func _on_coins_spent(amount: int, _source: StringName) -> void:
	_spent_coins += maxi(0, amount)


func _on_offer_opened(
	_offer_number: int,
	_cost: int,
	card_count: int
) -> void:
	for index: int in range(card_count):
		var definition: UpgradeDefinition = _upgrades.get_card_definition(index)
		if definition == null:
			continue
		var pool_id: StringName = (
			GENERAL_POOL_ID
			if definition.card_type == UpgradeDefinition.CardType.GENERAL
			else definition.branch_id
		)
		_offer_slot_counts[pool_id] = int(_offer_slot_counts.get(pool_id, 0)) + 1


func _on_card_selected_by_id(
	card_id: StringName,
	offer_number: int,
	cost: int
) -> void:
	var definition: UpgradeDefinition = _upgrades.catalog.get_definition(card_id)
	if definition == null:
		return
	var specialization: bool = (
		definition.card_type == UpgradeDefinition.CardType.SPECIALIZATION
	)
	_purchase_timeline.append({
		"time_seconds": get_current_survival_seconds(),
		"purchase_number": offer_number,
		"card_id": card_id,
		"branch_id": definition.branch_id,
		"cost": cost,
		"coins_after": _economy.get_coins(),
		"specialization": specialization,
	})
	if specialization:
		_specialization_purchase_numbers.append(offer_number)


func _on_run_ended(reason: StringName) -> void:
	_final_snapshot = RunStatisticsSnapshot.new(
		get_current_survival_seconds(),
		_physical_kills,
		_economy.get_coins(),
		_upgrades.get_completed_purchase_count(),
		reason,
		_earned_coins,
		_spent_coins,
		_purchase_timeline,
		_offer_slot_counts,
		_specialization_purchase_numbers
	)
	print(_final_snapshot.get_balance_summary_text())
	SessionRecordsStore.register_result(_final_snapshot)
	run_finalized.emit(_final_snapshot)


func _on_run_state_changed(previous_state: int, new_state: int) -> void:
	if new_state != GameFlowController.RunState.START_DELAY:
		return
	if previous_state == GameFlowController.RunState.MANUAL_PAUSE:
		return
	reset_for_run()
