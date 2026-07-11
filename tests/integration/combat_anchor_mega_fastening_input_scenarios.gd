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

	# Match live gameplay: one outer anchor is already attached on each side
	# before the player buys Mega Fastening.
	_install_with_action(anchors, &"gp_anchor_1", 0)
	_install_with_action(anchors, &"gp_anchor_4", 3)
	assert(not anchors.is_second_winch_pair_enabled())

	assert(combat.apply_upgrade_effect(_flag(
		CombatAnchorUpgradeRuntime.REINFORCED_WIND_THRESHOLD
	)))
	assert(combat.apply_upgrade_effect(_flag(
		CombatAnchorUpgradeRuntime.SECOND_WINCH_PAIR
	)))
	assert(anchors.is_second_winch_pair_enabled())

	# The newly exposed inner winches must remain fully operable.
	_install_with_action(anchors, &"gp_anchor_2", 1)
	_install_with_action(anchors, &"gp_anchor_3", 2)
	for anchor_id: int in range(4):
		assert(anchors.is_path_available(anchor_id))

	print("Combat anchor mega fastening input scenarios passed")
	quit()


func _install_with_action(
	anchors: CombatAnchorHostSystem,
	action: StringName,
	anchor_id: int
) -> void:
	_send_anchor_action(anchors, action)
	assert(anchors.get_anchor_state(anchor_id) == AnchorRuntime.State.INSTALLING)
	anchors._physics_process(anchors.get_effective_install_duration(anchor_id) + 0.1)
	assert(anchors.is_path_available(anchor_id))


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
