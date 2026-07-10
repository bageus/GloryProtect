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

	var anchors: CombatAnchorHostSystem = game.get_node("World/AnchorSystem")
	var platform: PlatformController = game.get_node("World/Platform")
	var orbs: GroundOrbRegistry = game.get_node("World/GroundOrbRegistry")
	assert(anchors != null)
	assert(platform != null)
	assert(orbs != null)

	platform.position.x = orbs.get_world_x(2)
	platform.horizontal_velocity = 0.0
	anchors.set_operator_assigned(AnchorRuntime.Side.LEFT, true)
	assert(anchors.is_in_installation_zone())
	assert(anchors.get_anchor_state(0) == AnchorRuntime.State.STOWED)

	var install_event := InputEventAction.new()
	install_event.action = &"gp_anchor_1"
	install_event.pressed = true
	install_event.strength = 1.0
	anchors._unhandled_input(install_event)
	assert(anchors.get_anchor_state(0) == AnchorRuntime.State.INSTALLING)

	anchors._physics_process(anchors.balance.install_duration + 0.1)
	assert(anchors.get_anchor_state(0) == AnchorRuntime.State.ATTACHED)
	assert(anchors.is_path_available(0))

	var remove_event := InputEventAction.new()
	remove_event.action = &"gp_anchor_1"
	remove_event.pressed = true
	remove_event.strength = 1.0
	anchors._unhandled_input(remove_event)
	assert(anchors.get_anchor_state(0) == AnchorRuntime.State.STOWED)
	assert(not anchors.is_path_available(0))

	print("Anchor input installation scenarios passed")
	quit()


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
