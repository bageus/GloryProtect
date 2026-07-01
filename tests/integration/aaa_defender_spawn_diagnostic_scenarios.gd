extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	paused = false
	var game := GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	_disable_spawners(game)
	await process_frame
	await process_frame
	flow.state = GameFlowController.RunState.RUNNING
	var economy: RunEconomy = game.get_node("RunEconomy")
	var coins: int = economy.get_coins()
	if coins > 0:
		economy.spend_coins(coins, &"diagnostic")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var roles := game.get_node(
		"World/Platform/CrewRoleManager"
	) as ShooterCrewRoleManagerPolished
	flow.begin_card_selection()
	var added: Defender = crew.add_defender()
	var defender_id: int = added.defender_id
	flow.finish_card_selection()

	for frame: int in range(241):
		if frame % 30 == 0:
			var runtime: CrewAssignmentRuntime = roles.get_assignment(defender_id)
			var state_value: int = -1
			if runtime != null:
				state_value = runtime.state
			print(
				"diagnostic frame=%d tree_paused=%s flow=%d runtime=%d pos=%.2f target=%.2f moving=%s movement_paused=%s speed=%.2f" % [
					frame,
					paused,
					flow.state,
					state_value,
					added.position.x,
					added.movement.get_target_x(),
					added.movement.is_moving(),
					added.movement.is_paused(),
					added.movement.move_speed,
				]
			)
		await physics_frame

	game.queue_free()
	await process_frame
	print("Defender spawn diagnostic scenarios passed")
	quit()


func _disable_spawners(game: Node) -> void:
	var paths: Array[NodePath] = [
		NodePath("World/BoardingSpawnDirector"),
		NodePath("World/FlyingEnemySpawnDirector"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
	]
	for path: NodePath in paths:
		if not game.has_node(path):
			continue
		var node: Node = game.get_node(path)
		node.set_process(false)
		node.set_physics_process(false)
