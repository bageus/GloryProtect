class_name AppShellScene
extends AppShell


func start_visual_test_game() -> void:
	get_tree().paused = false
	_waiting_action = &""
	_waiting_button = null
	if _active_game != null and is_instance_valid(_active_game):
		_game_host.remove_child(_active_game)
		_active_game.queue_free()
	_active_game = null
	_game_flow = null
	_screen = Screen.NONE
	_set_overlay_visible(false)
	call_deferred("_spawn_visual_test_game")


func _spawn_visual_test_game() -> void:
	_active_game = GAME_SCENE.instantiate() as Node2D
	_game_flow = _active_game.get_node("GameFlowController") as GameFlowController
	_game_flow.start_delay_seconds = 0.0
	_game_host.add_child(_active_game)
	_game_flow.restart_requested.connect(_on_restart_requested)
	_game_flow.run_state_changed.connect(_on_run_state_changed)
	_game_flow.start_delay_remaining = 0.0
	_game_flow.call_deferred("_set_state", GameFlowController.RunState.RUNNING)
	_attach_visual_test_panel.call_deferred()


func _attach_visual_test_panel() -> void:
	if _active_game == null or not is_instance_valid(_active_game):
		return
	var panel := VisualUpgradeTestPanel.new()
	panel.name = "VisualUpgradeTestPanel"
	_active_game.add_child(panel)
	panel.configure(_active_game)


func _show_main_menu() -> void:
	_screen = Screen.MAIN
	_settings_return_screen = Screen.MAIN
	_set_overlay_visible(true)
	_clear_body()
	_title_label.text = "GLORY PROTECT"
	var primary_text: String = (
		"Продолжить"
		if _active_game != null and is_instance_valid(_active_game)
		else "Новая игра"
	)
	_add_button(primary_text, start_new_game)
	_add_button("Начать игру тест", start_visual_test_game)
	_add_button("Настройки", _open_settings_from_main)
	_add_button("Выйти из игры", _quit_game)
	_focus_first_button()


func _open_pause_menu() -> void:
	if _game_flow == null:
		return
	if _game_flow.state not in [
		GameFlowController.RunState.START_DELAY,
		GameFlowController.RunState.RUNNING,
		GameFlowController.RunState.CARD_SELECTION,
	]:
		return
	# The state-change signal builds the pause screen exactly once.
	_game_flow.toggle_manual_pause()


func _clear_body() -> void:
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
