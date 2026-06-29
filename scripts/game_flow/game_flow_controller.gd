class_name GameFlowController
extends Node

signal run_state_changed(previous_state: RunState, new_state: RunState)
signal run_started
signal run_paused
signal run_resumed
signal run_ended(reason: StringName)
signal restart_requested

enum RunState {
	BOOT,
	START_DELAY,
	RUNNING,
	CARD_SELECTION,
	MANUAL_PAUSE,
	GAME_OVER,
}

@export_range(0.0, 10.0, 0.1) var start_delay_seconds: float = 3.0

var state: RunState = RunState.BOOT
var start_delay_remaining: float = 0.0
var game_over_reason: StringName = &""
var _manual_pause_resume_state: RunState = RunState.RUNNING


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	start_run()


func _process(delta: float) -> void:
	if state != RunState.START_DELAY:
		return
	start_delay_remaining = maxf(0.0, start_delay_remaining - delta)
	if is_zero_approx(start_delay_remaining):
		_set_state(RunState.RUNNING)
		run_started.emit()


func start_run() -> void:
	get_tree().paused = false
	game_over_reason = &""
	start_delay_remaining = start_delay_seconds
	_set_state(RunState.START_DELAY)


func restart_run() -> void:
	restart_requested.emit()
	get_tree().paused = false
	if get_tree().get_first_node_in_group(&"app_shell") == null:
		get_tree().reload_current_scene()


func toggle_manual_pause() -> void:
	match state:
		RunState.START_DELAY, RunState.RUNNING:
			_manual_pause_resume_state = state
			_set_state(RunState.MANUAL_PAUSE)
			get_tree().paused = true
			run_paused.emit()
		RunState.MANUAL_PAUSE:
			get_tree().paused = false
			_set_state(_manual_pause_resume_state)
			run_resumed.emit()
		_:
			pass


func begin_card_selection() -> void:
	if state != RunState.RUNNING:
		return
	_set_state(RunState.CARD_SELECTION)
	get_tree().paused = true


func finish_card_selection() -> void:
	if state != RunState.CARD_SELECTION:
		return
	get_tree().paused = false
	_set_state(RunState.RUNNING)


func end_run(reason: StringName) -> void:
	if state == RunState.GAME_OVER:
		return
	get_tree().paused = false
	game_over_reason = reason
	_set_state(RunState.GAME_OVER)
	run_ended.emit(reason)


func is_world_simulation_active() -> bool:
	return state == RunState.START_DELAY or state == RunState.RUNNING


func get_state_name() -> String:
	return RunState.keys()[state]


func _set_state(new_state: RunState) -> void:
	if new_state == state:
		return
	var previous_state := state
	state = new_state
	run_state_changed.emit(previous_state, new_state)
