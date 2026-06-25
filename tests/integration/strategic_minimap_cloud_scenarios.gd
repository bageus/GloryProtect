extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame
	var flow: GameFlowController = game.get_node("GameFlowController")
	var minimap: StrategicMinimap = game.get_node("CanvasLayer/StrategicMinimap")
	flow.state = GameFlowController.RunState.RUNNING
	assert(minimap.get_visual_kind(1) == &"single")
	assert(minimap.get_visual_kind(2) == &"pair")
	assert(minimap.get_visual_kind(3) == &"cloud")
	await _wait_frames(3)
	var elapsed: float = minimap.get_visual_elapsed()
	assert(elapsed > 0.0)
	flow.state = GameFlowController.RunState.MANUAL_PAUSE
	await _wait_frames(5)
	assert(is_equal_approx(minimap.get_visual_elapsed(), elapsed))
	print("Strategic minimap cloud scenarios passed")
	quit()

func _wait_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await process_frame
