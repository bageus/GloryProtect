extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.state = GameFlowController.RunState.RUNNING
	_disable_spawners(game)

	var anchors: AnchorSystem = game.get_node("World/AnchorSystem")
	var shake := game.get_node("WorldShakeController") as WorldShakeController
	assert(shake != null)
	shake.set_process(false)
	var base_transform: Transform2D = root.get_viewport().canvas_transform

	anchors.anchor_recovery_started.emit(0, &"enemy_rope_damage", 0)
	assert(shake.get_trigger_count() == 0)
	assert(not shake.is_shaking())
	anchors.anchor_removed.emit(0)
	assert(shake.get_trigger_count() == 0)

	anchors.anchor_recovery_started.emit(0, &"wind_overload", 0)
	assert(shake.get_trigger_count() == 1)
	assert(shake.is_shaking())
	shake._process(shake.duration * 0.5)
	assert(root.get_viewport().canvas_transform != base_transform)
	shake._process(shake.duration)
	assert(not shake.is_shaking())
	assert(root.get_viewport().canvas_transform == base_transform)

	print("Tension break shake scenarios passed")
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
