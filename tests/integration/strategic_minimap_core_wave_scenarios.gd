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

	var minimap: StrategicMinimap = game.get_node("CanvasLayer/StrategicMinimap")
	var shield: ShieldSystem = game.get_node("ShieldSystem")
	var waves: StrategicWaveSystem = game.get_node("World/StrategicWaveSystem")
	assert(minimap != null)
	assert(shield != null)
	assert(waves != null)
	minimap.size = Vector2(640.0, 96.0)
	await process_frame

	assert(minimap.get_core_marker_count() == shield.get_section_count())
	var previous_x: float = -INF
	for section_id: int in range(shield.get_section_count()):
		var marker_position: Vector2 = minimap.get_core_marker_position(section_id)
		assert(marker_position.x > previous_x)
		assert(marker_position.x > 0.0)
		assert(marker_position.x < minimap.get_map_width())
		assert(marker_position.y > 30.0)
		assert(marker_position.y < minimap.size.y - 18.0)
		previous_x = marker_position.x

	assert(minimap.get_active_energy_wave_count() == 0)
	waves.strategic_enemy_impacted.emit(2, 5.0)
	await process_frame
	assert(minimap.get_active_energy_wave_count() == 1)
	assert(minimap.has_energy_wave_for_section(2))

	waves.strategic_enemy_impacted.emit(0, 3.0)
	await process_frame
	assert(minimap.get_active_energy_wave_count() == 2)
	assert(minimap.has_energy_wave_for_section(0))

	await create_timer(minimap.energy_wave_duration + 0.15).timeout
	assert(minimap.get_active_energy_wave_count() == 0)

	minimap.debug_emit_energy_wave(-1)
	minimap.debug_emit_energy_wave(shield.get_section_count())
	assert(minimap.get_active_energy_wave_count() == 0)

	print("Strategic minimap core wave scenarios passed")
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
