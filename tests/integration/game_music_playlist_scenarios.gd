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
	_disable_spawners(game)

	var music: GameMusicController = game.get_node("GameMusicController")
	assert(music != null)
	assert(music.get_gameplay_track_count() == 4)
	var paths: PackedStringArray = music.get_gameplay_track_paths_for_tests()
	assert(paths.has("res://audio/Melodic Drive Core.mp3"))
	assert(paths.has("res://audio/Melodic Drive Core2.mp3"))
	assert(paths.has("res://audio/Melodic Drive Core3.mp3"))
	assert(paths.has("res://audio/Melodic core.mp3"))

	flow.state = GameFlowController.RunState.RUNNING
	music.refresh_music_state_for_tests()
	assert(music.is_gameplay_music_active())
	assert(music.get_current_gameplay_track_index() == 0)
	music.advance_gameplay_track_for_tests()
	assert(music.is_gameplay_music_active())
	assert(music.get_current_gameplay_track_index() == 1)
	music.advance_gameplay_track_for_tests()
	music.advance_gameplay_track_for_tests()
	music.advance_gameplay_track_for_tests()
	assert(music.get_current_gameplay_track_index() == 0)

	flow.state = GameFlowController.RunState.GAME_OVER
	music.refresh_music_state_for_tests()
	assert(music.is_game_over_music_active())
	var index_before: int = music.get_current_gameplay_track_index()
	music.advance_gameplay_track_for_tests()
	assert(music.get_current_gameplay_track_index() == index_before)

	print("Game music playlist scenarios passed")
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
