extends SceneTree

const APP_SCENE := preload("res://scenes/app/app_shell.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var shell := APP_SCENE.instantiate() as AppShell
	root.add_child(shell)
	await process_frame
	assert(shell.get_current_screen() == AppShell.Screen.MAIN)
	assert(shell.get_active_game() == null)
	assert(_get_direct_button_texts(shell) == [
		"Новая игра",
		"Начать игру тест",
		"Настройки",
		"Выйти из игры",
	])

	shell.start_new_game()
	await process_frame
	await process_frame
	var first_game: Node2D = shell.get_active_game()
	assert(first_game != null)
	var flow := first_game.get_node("GameFlowController") as GameFlowController
	assert(flow.state in [
		GameFlowController.RunState.START_DELAY,
		GameFlowController.RunState.RUNNING,
	])
	assert(shell.get_current_screen() == AppShell.Screen.NONE)

	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	shell._unhandled_input(escape)
	assert(shell.get_current_screen() == AppShell.Screen.PAUSE)
	assert(flow.state == GameFlowController.RunState.MANUAL_PAUSE)
	assert(paused)
	assert(_get_direct_button_texts(shell) == [
		"Продолжить",
		"Перезапустить забег",
		"Настройки",
		"Выйти из игры",
	])

	shell._unhandled_input(escape)
	assert(shell.get_current_screen() == AppShell.Screen.NONE)
	assert(not paused)
	assert(flow.state in [
		GameFlowController.RunState.START_DELAY,
		GameFlowController.RunState.RUNNING,
	])

	flow.state = GameFlowController.RunState.RUNNING
	flow.begin_card_selection()
	assert(flow.state == GameFlowController.RunState.CARD_SELECTION)
	assert(paused)
	shell._unhandled_input(escape)
	assert(shell.get_current_screen() == AppShell.Screen.PAUSE)
	assert(flow.state == GameFlowController.RunState.MANUAL_PAUSE)
	assert(paused)
	shell._unhandled_input(escape)
	assert(shell.get_current_screen() == AppShell.Screen.NONE)
	assert(flow.state == GameFlowController.RunState.CARD_SELECTION)
	assert(paused)
	flow.finish_card_selection()
	assert(flow.state == GameFlowController.RunState.RUNNING)
	assert(not paused)

	shell.restart_active_run()
	await process_frame
	await process_frame
	var second_game: Node2D = shell.get_active_game()
	assert(second_game != null)
	assert(second_game != first_game)
	assert(not paused)

	shell.show_main_menu()
	await process_frame
	assert(shell.get_current_screen() == AppShell.Screen.MAIN)
	assert(_get_direct_button_texts(shell)[1] == "Начать игру тест")
	(shell as AppShellScene).start_visual_test_game()
	await process_frame
	await process_frame
	await process_frame
	var test_game: Node2D = shell.get_active_game()
	assert(test_game != null)
	assert(test_game != second_game)
	var test_flow: GameFlowController = test_game.get_node("GameFlowController")
	assert(test_flow.start_delay_seconds == 0.0)
	assert(test_flow.state == GameFlowController.RunState.RUNNING)
	var test_panel: VisualUpgradeTestPanel = test_game.get_node(
		"VisualUpgradeTestPanel"
	) as VisualUpgradeTestPanel
	assert(test_panel != null)
	assert(test_panel.is_test_panel_ready_for_tests())
	assert(test_panel.get_toggle_count_for_tests() > 0)
	assert(test_panel.is_card_ui_suppressed_for_tests())

	print("App shell menu scenarios passed")
	quit()


func _get_direct_button_texts(shell: AppShell) -> Array[String]:
	var result: Array[String] = []
	var body := shell.get("_body") as VBoxContainer
	assert(body != null)
	for child: Node in body.get_children():
		if child is Button:
			result.append((child as Button).text)
	return result
