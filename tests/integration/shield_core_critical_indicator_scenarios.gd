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

	var shield: ShieldCoreShieldSystem = game.get_node("ShieldSystem")
	var platform: PlatformController = game.get_node("World/Platform")
	var camera: Camera2D = game.get_node("World/Platform/Camera2D")
	var indicator: ShieldCoreCriticalIndicator = game.get_node(
		"CanvasLayer/ShieldCoreCriticalIndicator"
	)
	assert(shield != null)
	assert(platform != null)
	assert(camera != null)
	assert(indicator != null)
	camera.position_smoothing_enabled = false
	platform.position.x = 0.0
	await process_frame

	assert(indicator.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(indicator.get_visible_indicator_count() == 0)

	shield.set_health(0, 20.0)
	await process_frame
	assert(indicator.is_indicator_visible(0))
	assert(indicator.is_indicator_offscreen(0))
	assert(indicator.get_indicator_position(0).x <= indicator.edge_margin + 1.0)

	shield.set_health(2, 20.0)
	await process_frame
	assert(indicator.is_indicator_visible(2))
	assert(not indicator.is_indicator_offscreen(2))
	assert(indicator.get_visible_indicator_count() == 2)
	indicator._process(indicator.onscreen_visible_seconds + 0.1)
	assert(not indicator.is_indicator_visible(2))
	assert(indicator.is_indicator_visible(0))

	platform.position.x = 2000.0
	await process_frame
	assert(indicator.is_indicator_visible(2))
	assert(indicator.is_indicator_offscreen(2))
	assert(is_equal_approx(indicator.get_onscreen_elapsed(2), 0.0))

	shield.set_health(0, shield.get_max_health())
	shield.set_health(2, shield.get_max_health())
	await process_frame
	assert(not indicator.is_indicator_visible(0))
	assert(not indicator.is_indicator_visible(2))
	assert(indicator.get_visible_indicator_count() == 0)

	platform.position.x = 0.0
	shield.set_health(0, 20.0)
	shield.set_health(4, 20.0)
	await process_frame
	assert(indicator.is_indicator_visible(0))
	assert(indicator.is_indicator_visible(4))
	assert(indicator.get_visible_indicator_count() == 2)
	assert(indicator.is_indicator_offscreen(0))
	assert(indicator.is_indicator_offscreen(4))

	print("Shield core critical indicator scenarios passed")
	quit()


func _stabilize_world(game: Node) -> void:
	var paths: Array[NodePath] = [
		NodePath("World/BoardingSpawnDirector"),
		NodePath("World/FlyingEnemySpawnDirector"),
		NodePath("World/StrategicWaveSystem"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
		NodePath("World/ShieldRechargeController"),
	]
	for path: NodePath in paths:
		if not game.has_node(path):
			continue
		var system: Node = game.get_node(path)
		system.set_process(false)
		system.set_physics_process(false)
