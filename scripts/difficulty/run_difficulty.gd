class_name RunDifficulty
extends Node

signal difficulty_changed(
	previous_value: float,
	current_value: float,
	elapsed_seconds: float
)
signal overtime_tier_changed(
	previous_tier: int,
	current_tier: int,
	elapsed_seconds: float
)
signal progression_reset

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export var balance: RunDifficultyBalance

var _elapsed_seconds: float = 0.0
var _normalized_difficulty: float = 0.0
var _overtime_tier: int = 0

@onready var _game_flow: GameFlowController = get_node(game_flow_path)


func _ready() -> void:
	assert(balance != null, "RunDifficulty requires RunDifficultyBalance")
	_game_flow.run_state_changed.connect(_on_run_state_changed)
	reset_for_run()


func _process(delta: float) -> void:
	if _game_flow.state != GameFlowController.RunState.RUNNING:
		return
	_set_elapsed_seconds(_elapsed_seconds + maxf(0.0, delta))


func get_elapsed_seconds() -> float:
	return _elapsed_seconds


func get_normalized() -> float:
	return _normalized_difficulty


func get_percent() -> float:
	return _normalized_difficulty * 100.0


func get_overtime_tier() -> int:
	return _overtime_tier


func reset_for_run() -> void:
	_set_elapsed_seconds(0.0)
	progression_reset.emit()


func set_debug_elapsed_seconds(value: float) -> void:
	_set_elapsed_seconds(value)


func _set_elapsed_seconds(value: float) -> void:
	var safe_elapsed: float = maxf(0.0, value)
	var next_difficulty: float = balance.get_normalized_for_elapsed(safe_elapsed)
	var next_overtime_tier: int = balance.get_overtime_tier_for_elapsed(safe_elapsed)
	var previous_difficulty: float = _normalized_difficulty
	var previous_overtime_tier: int = _overtime_tier
	_elapsed_seconds = safe_elapsed
	_normalized_difficulty = next_difficulty
	_overtime_tier = next_overtime_tier
	if not is_equal_approx(previous_difficulty, next_difficulty):
		difficulty_changed.emit(
			previous_difficulty,
			_normalized_difficulty,
			_elapsed_seconds
		)
	if previous_overtime_tier != next_overtime_tier:
		overtime_tier_changed.emit(
			previous_overtime_tier,
			_overtime_tier,
			_elapsed_seconds
		)


func _on_run_state_changed(previous_state: int, new_state: int) -> void:
	if new_state != GameFlowController.RunState.START_DELAY:
		return
	if previous_state == GameFlowController.RunState.MANUAL_PAUSE:
		return
	reset_for_run()
