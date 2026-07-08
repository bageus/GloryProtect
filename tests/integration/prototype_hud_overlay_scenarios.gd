extends SceneTree

const BASE_SCENE := preload("res://scenes/game/game_root.tscn")
const TEST_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _assert_scene_hides_overlay(BASE_SCENE)
	await _assert_scene_hides_overlay(TEST_SCENE)
	print("Prototype HUD overlay scenarios passed")
	quit()


func _assert_scene_hides_overlay(scene: PackedScene) -> void:
	var game: Node2D = scene.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	flow.state = GameFlowController.RunState.RUNNING
	_disable_spawners(game)

	var hud: PrototypeHUD = game.get_node("CanvasLayer/PrototypeHUD") as PrototypeHUD
	assert(hud != null)
	assert(hud.has_node("CrewCommandPanel"))
	assert(hud.get_node_or_null("TelemetryPanel/Margin/VBox/BuildableLabel") != null)
	assert(hud.get_node_or_null("TelemetryPanel/Margin/VBox/TurretLabel") != null)
	assert(not hud.is_telemetry_overlay_visible_for_tests())
	assert(not hud.is_instant_anchor_remove_prompt_visible_for_tests())

	var event := InputEventKey.new()
	event.keycode = KEY_F10
	event.pressed = true
	hud.call("_unhandled_input", event)
	await process_frame
	assert(not hud.is_telemetry_overlay_visible_for_tests())
	assert(not hud.is_instant_anchor_remove_prompt_visible_for_tests())

	var telemetry: Control = hud.get_node_or_null("TelemetryPanel") as Control
	if telemetry != null:
		telemetry.visible = true
		await process_frame
		assert(not hud.is_telemetry_overlay_visible_for_tests())
	game.queue_free()
	await process_frame


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
