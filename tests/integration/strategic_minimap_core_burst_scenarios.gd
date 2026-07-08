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

	var shield_core: ShieldCoreSystem = game.get_node("World/ShieldCoreSystem")
	var minimap: StrategicMinimapPolished = game.get_node(
		"CanvasLayer/StrategicMinimap"
	) as StrategicMinimapPolished
	var pulse_visual: ShieldCorePulseVisual = game.get_node(
		"World/ShieldCorePulseVisual"
	) as ShieldCorePulseVisual
	assert(shield_core != null)
	assert(minimap != null)
	assert(pulse_visual != null)
	minimap.size = Vector2(640.0, 96.0)

	assert(minimap.get_active_core_burst_count_for_tests() == 0)
	assert(pulse_visual.get_active_pulse_count() == 0)

	var left_direction: Vector2 = minimap.get_core_burst_direction_for_section_for_tests(0)
	var center_direction: Vector2 = minimap.get_core_burst_direction_for_section_for_tests(2)
	var right_direction: Vector2 = minimap.get_core_burst_direction_for_section_for_tests(4)
	assert(left_direction.x < 0.0)
	assert(left_direction.y < 0.0)
	assert(absf(center_direction.x) < 0.01)
	assert(center_direction.y < 0.0)
	assert(right_direction.x > 0.0)
	assert(right_direction.y < 0.0)

	shield_core.surge_pulse_requested.emit(
		0,
		ShieldCoreSystem.SurgePulseSource.GROUND_CORE
	)
	await process_frame
	assert(minimap.get_active_core_burst_count_for_tests() == 1)
	assert(minimap.has_core_burst_for_section_for_tests(0))
	assert(pulse_visual.get_active_pulse_count() == 0)
	var left_angle: float = minimap.get_latest_core_burst_angle_for_tests()

	shield_core.surge_pulse_requested.emit(
		4,
		ShieldCoreSystem.SurgePulseSource.PLATFORM_CORE
	)
	await process_frame
	assert(minimap.get_active_core_burst_count_for_tests() == 2)
	assert(minimap.has_core_burst_for_section_for_tests(4))
	assert(pulse_visual.get_active_pulse_count() == 0)
	var right_angle: float = minimap.get_latest_core_burst_angle_for_tests()
	assert(right_angle > left_angle)

	minimap.call("_process", minimap.core_burst_duration + 0.1)
	assert(minimap.get_active_core_burst_count_for_tests() == 0)

	print("Strategic minimap core burst scenarios passed")
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
