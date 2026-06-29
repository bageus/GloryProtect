class_name AppShellScene
extends AppShell


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
