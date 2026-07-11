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

	var platform: PlatformController = game.get_node("World/Platform")
	var orbs: GroundOrbRegistry = game.get_node("World/GroundOrbRegistry")
	var anchors: CombatAnchorHostSystem = game.get_node("World/AnchorSystem")
	var combat: CombatAnchorSystem = game.get_node("World/CombatAnchorSystem")
	assert(platform != null)
	assert(orbs != null)
	assert(anchors != null)
	assert(combat != null)

	platform.position.x = orbs.get_world_x(2)
	platform.horizontal_velocity = 0.0
	anchors.set_operator_assigned(AnchorRuntime.Side.LEFT, true)
	anchors.set_operator_assigned(AnchorRuntime.Side.RIGHT, true)
	assert(anchors.is_in_installation_zone())

	assert(combat.apply_upgrade_effect(_flag(
		CombatAnchorUpgradeRuntime.REINFORCED_WIND_THRESHOLD
	)))
	assert(combat.apply_upgrade_effect(_flag(
		CombatAnchorUpgradeRuntime.SECOND_WINCH_PAIR
	)))
	assert(anchors.is_second_winch_pair_enabled())

	_send_anchor_action(anchors, &"gp_anchor_1")
	assert(anchors.get_anchor_state(0) == AnchorRuntime.State.INSTALLING)
	anchors._physics_process(anchors.get_effective_install_duration(0) + 0.1)
	assert(anchors.is_path_available(0))

	_send_anchor_action(anchors, &"gp_anchor_2")
	assert(anchors.get_anchor_state(1) == AnchorRuntime.State.INSTALLING)
	anchors._physics_process(anchors.get_effective_install_duration(1) + 0.1)
	assert(anchors.is_path_available(1))

	_send_anchor_action(anchors, &"gp_anchor_4")
	assert(anchors.get_anchor_state(3) == AnchorRuntime.State.INSTALLING)
	anchors._physics_process(anchors.get_effective_install_duration(3) + 0.1)
	assert(anchors.is_path_available(3))

	_send_anchor_action(anchors, &"gp_anchor_3")
	assert(anchors.get_anchor_state(2) == AnchorRuntime.State.INSTALLING)
	anchors._physics_process(anchors.get_effective_install_duration(2) + 0.1)
	assert(anchors.is_path_available(2))

	print("Combat anchor mega fastening input scenarios passed")
	quit()


func _send_anchor_action(anchors: CombatAnchorHostSystem, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	event.strength = 1.0
	anchors._unhandled_input(event)


func _flag(target_id: StringName) -> UpgradeEffectDefinition:
	var effect := UpgradeEffectDefinition.new()
	effect.effect_type = UpgradeEffectDefinition.EffectType.DOMAIN_FLAG
	effect.target_id = target_id
	return effect


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
