class_name GameOverPanel
extends Control

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("RunStatistics") var run_statistics_path: NodePath

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _statistics: RunStatistics = get_node(run_statistics_path)
@onready var _reason_label: Label = %ReasonLabel
@onready var _time_label: Label = %TimeLabel
@onready var _kills_label: Label = %KillsLabel
@onready var _coins_label: Label = %CoinsLabel
@onready var _upgrades_label: Label = %UpgradesLabel
@onready var _session_label: Label = %SessionLabel
@onready var _best_time_label: Label = %BestTimeLabel
@onready var _best_kills_label: Label = %BestKillsLabel
@onready var _restart_button: Button = %RestartButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_statistics.run_finalized.connect(_on_run_finalized)
	_game_flow.run_state_changed.connect(_on_run_state_changed)
	_restart_button.pressed.connect(_on_restart_pressed)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action(&"ui_accept"):
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		_on_restart_pressed()


func _on_run_finalized(snapshot: RunStatisticsSnapshot) -> void:
	_reason_label.text = _get_reason_text(snapshot.end_reason)
	_time_label.text = "Время выживания: %s" % _format_duration(
		snapshot.survival_seconds
	)
	_kills_label.text = "Физических врагов уничтожено: %d" % (
		snapshot.physical_kills
	)
	_coins_label.text = "Монет осталось: %d" % snapshot.remaining_coins
	_upgrades_label.text = "Карточек куплено: %d" % snapshot.purchased_upgrades
	_session_label.text = "Забегов в текущем запуске: %d" % (
		_statistics.get_session_completed_runs()
	)
	_best_time_label.text = "Лучшее время: %s" % _format_duration(
		_statistics.get_session_best_survival_seconds()
	)
	_best_kills_label.text = "Лучший результат по убийствам: %d" % (
		_statistics.get_session_best_physical_kills()
	)
	visible = true
	_restart_button.grab_focus()


func _on_run_state_changed(_previous_state: int, new_state: int) -> void:
	if new_state == GameFlowController.RunState.GAME_OVER:
		return
	visible = false


func _on_restart_pressed() -> void:
	_game_flow.restart_run()


func _format_duration(total_seconds: float) -> String:
	var rounded_seconds: int = maxi(0, floori(total_seconds))
	var minutes: int = floori(float(rounded_seconds) / 60.0)
	var seconds: int = rounded_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func _get_reason_text(reason: StringName) -> String:
	match reason:
		&"shield_section_destroyed":
			return "СЕКЦИЯ ЩИТА РАЗРУШЕНА"
		&"all_defenders_dead":
			return "ЭКИПАЖ УНИЧТОЖЕН"
		_:
			return "ЗАБЕГ ЗАВЕРШЁН"
