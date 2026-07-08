extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	flow.state = GameFlowController.RunState.RUNNING
	_disable_spawners(game)

	var audio: GameAudioController = game.get_node("GameAudioController")
	var enemies: BoardingEnemyRegistry = game.get_node("World/BoardingEnemyRegistry")
	assert(audio != null)
	assert(enemies != null)
	assert(audio.get_loaded_sound_ids().has(GameAudioController.SOUND_BOOM_BUG))
	assert(audio.get_trigger_count(GameAudioController.SOUND_BOOM_BUG) == 0)
	assert(audio.get_trigger_count(GameAudioController.SOUND_MONSTER_DIE) == 0)

	enemies.enemy_removed.emit(10, &"arming")
	await process_frame
	assert(audio.get_trigger_count(GameAudioController.SOUND_BOOM_BUG) == 0)
	assert(audio.get_trigger_count(GameAudioController.SOUND_MONSTER_DIE) == 1)

	enemies.enemy_removed.emit(11, &"rope_sabotage")
	await process_frame
	assert(audio.get_trigger_count(GameAudioController.SOUND_BOOM_BUG) == 1)
	assert(audio.get_trigger_count(GameAudioController.SOUND_MONSTER_DIE) == 2)
	assert(audio.get_active_one_shot_count_for_tests(GameAudioController.SOUND_BOOM_BUG) == 1)

	enemies.enemy_removed.emit(12, &"rope_sabotage")
	enemies.enemy_removed.emit(13, &"rope_sabotage")
	await process_frame
	assert(audio.get_trigger_count(GameAudioController.SOUND_BOOM_BUG) == audio.boom_bug_max_concurrent)
	assert(audio.get_trigger_count(GameAudioController.SOUND_MONSTER_DIE) == 4)

	print("Boom bug audio scenarios passed")
	quit()


func _disable_spawners(game: Node) -> void:
	var paths: Array[NodePath] = [
		NodePath("World/BoardingSpawnDirector"),
		NodePath("World/FlyingEnemySpawnDirector"),
		NodePath("World/StrategicWaveSystem"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
	]
	for path: NodePath in paths:
		if not game.has_node(path):
			continue
		var node: Node = game.get_node(path)
		node.set_process(false)
		node.set_physics_process(false)
