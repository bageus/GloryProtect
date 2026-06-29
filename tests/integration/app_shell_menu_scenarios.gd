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
