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
	var economy: RunEconomy = game.get_node("RunEconomy")
	var waves: StrategicWaveSystem = game.get_node("World/StrategicWaveSystem")
	var hud: PrototypeHUD = game.get_node("CanvasLayer/PrototypeHUD")
	_disable_spawners(game)
	flow.state = GameFlowController.RunState.RUNNING
	waves.balance.impact_interval = 0.01
	assert(waves.add_group(0, 3, 0.01, 0.0) >= 0)
	for _frame: int in range(120):
		if waves.get_active_group_count() == 0:
			break
		await physics_frame
	await process_frame
	assert(waves.get_active_group_count() == 0)
	assert(economy.get_coins() == 3)
	assert(hud.get_coin_counter_text() == "Монеты: 3")
	assert(hud.is_coin_gain_visible())
	assert(hud.get_coin_gain_text() == "+3")
	flow.state = GameFlowController.RunState.MANUAL_PAUSE
	await _wait_frames(5)
	assert(hud.is_coin_gain_visible())
	print("Strategic coin reward scenarios passed")
	quit()


func _disable_spawners(game: Node) -> void:
	for path: NodePath in [
		NodePath("World/BoardingSpawnDirector"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
	]:
		if game.has_node(path):
			var node: Node = game.get_node(path)
			node.set_process(false)
			node.set_physics_process(false)


func _wait_frames(count: int) -> void:
	for _frame: int in range(count):
		await process_frame
