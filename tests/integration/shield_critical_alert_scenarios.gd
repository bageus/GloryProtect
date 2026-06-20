extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root.tscn")

var _alert_count: int = 0
var _last_alert_ids: Array[int] = []


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var game_flow: GameFlowController = game.get_node("GameFlowController")
	var shield: ShieldSystem = game.get_node("ShieldSystem")
	var alerts: ShieldCriticalAlertController = game.get_node(
		"ShieldCriticalAlertController"
	)
	var presenter: Control = game.get_node(
		"CanvasLayer/ShieldCriticalAlertPresenter"
	)
	var message_label: Label = game.get_node(
		"CanvasLayer/ShieldCriticalAlertPresenter/MessageLabel"
	)
	var audio_player: AudioStreamPlayer = game.get_node(
		"CanvasLayer/ShieldCriticalAlertPresenter/AudioStreamPlayer"
	)
	alerts.critical_alert_raised.connect(_on_critical_alert_raised)

	game_flow.state = GameFlowController.RunState.RUNNING
	shield.set_health(0, 20.0)
	shield.set_health(1, 20.0)
	await process_frame
	assert(_alert_count == 1)
	assert(_last_alert_ids == [0, 1])
	assert(presenter.visible)
	assert(message_label.text == "КРИТИЧЕСКИЙ ЩИТ: S1, S2")
	assert(audio_player.stream is AudioStreamWAV)

	shield.set_health(0, 60.0)
	shield.set_health(0, 20.0)
	await process_frame
	assert(_alert_count == 2)
	assert(_last_alert_ids == [0])

	game_flow.begin_card_selection()
	shield.set_health(2, 20.0)
	await process_frame
	assert(_alert_count == 2)
	game_flow.finish_card_selection()

	print("Shield critical alert scenarios passed")
	quit()


func _on_critical_alert_raised(section_ids: Array[int]) -> void:
	_alert_count += 1
	_last_alert_ids = section_ids.duplicate()
