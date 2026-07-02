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
	_stabilize_world(game)

	var wind: WindSystem = game.get_node("WindSystem")
	var platform: PlatformController = game.get_node("World/Platform")
	var indicator: PlatformWindIndicator = game.get_node(
		"World/Platform/PlatformWindIndicator"
	)
	var placement: BuildablePlacementController = game.get_node(
		"BuildablePlacementController"
	)
	assert(wind != null)
	assert(platform != null)
	assert(indicator != null)
	assert(placement != null)
	assert(indicator.visible)
	assert(indicator.get_indicator_alpha() < 1.0)
	assert(indicator.get_label_mouse_filter() == Control.MOUSE_FILTER_IGNORE)
	assert(indicator.get_strength_text() == str(wind.strength_level))
	assert(indicator.get_indicator_rect().end.y < -platform.get_platform_height() * 0.5)

	wind.set_debug_state(1, 3)
	await process_frame
	assert(indicator.get_direction() == 1)
	assert(indicator.get_strength_text() == "3")
	assert(_get_tip_x(indicator.get_arrow_points_for_tests()) > 0.0)

	wind.set_debug_state(-1, 2)
	await process_frame
	assert(indicator.get_direction() == -1)
	assert(indicator.get_strength_text() == "2")
	assert(_get_tip_x(indicator.get_arrow_points_for_tests()) < 0.0)

	assert(placement.handle_primary_click(platform.get_cell_canvas_center(3)))
	await process_frame
	assert(placement.get_selected_cell_index() == 3)
	placement.clear_selection()
	await process_frame

	print("Platform wind indicator scenarios passed")
	quit()


func _get_tip_x(points: PackedVector2Array) -> float:
	assert(points.size() >= 4)
	return points[3].x


func _stabilize_world(game: Node) -> void:
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
		var system: Node = game.get_node(path)
		system.set_process(false)
		system.set_physics_process(false)
