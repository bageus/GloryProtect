extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	flow.state = GameFlowController.RunState.RUNNING
	_stabilize_world(game)

	var platform: PlatformController = game.get_node("World/Platform")
	var wind: WindSystem = game.get_node("WindSystem")
	var anchors: CombatAnchorHostSystem = game.get_node("World/AnchorSystem")
	var upgrades: CombatAnchorSystem = game.get_node("World/CombatAnchorSystem")
	wind.balance.level_forces = PackedFloat32Array([0.0, 0.0, 0.0])
	wind.balance.fluctuation_force = 0.0
	wind.set_debug_state(1, 1)
	platform.position.x = 0.0
	platform.horizontal_velocity = 0.0

	var rope_maximum: float = anchors.balance.rope_max_durability
	assert(is_equal_approx(
		anchors.get_rope_snapshot(2).maximum_durability,
		rope_maximum
	))
	assert(upgrades.apply_upgrade_effect(_scalar(
		CombatAnchorUpgradeRuntime.OVERLOAD_BONUS_SECONDS,
		1.0
	)))
	assert(upgrades.apply_upgrade_effect(_scalar(
		CombatAnchorUpgradeRuntime.OVERLOAD_BONUS_SECONDS,
		1.0
	)))
	assert(is_equal_approx(
		anchors.get_effective_overload_duration(),
		anchors.balance.overload_duration + 2.0
	))
	assert(is_equal_approx(
		anchors.get_rope_snapshot(2).maximum_durability,
		rope_maximum
	))

	assert(upgrades.apply_upgrade_effect(_scalar(
		CombatAnchorUpgradeRuntime.INSTALL_SPEED_BONUS_RATIO,
		0.2
	)))
	assert(upgrades.apply_upgrade_effect(_scalar(
		CombatAnchorUpgradeRuntime.INSTALL_SPEED_BONUS_RATIO,
		0.2
	)))
	var expected_first_duration: float = anchors.balance.install_duration / 1.4
	assert(is_equal_approx(
		anchors.get_effective_install_duration(2),
		expected_first_duration
	))

	assert(upgrades.apply_upgrade_effect(_flag(
		CombatAnchorUpgradeRuntime.STRONG
	)))
	assert(upgrades.apply_upgrade_effect(_flag(
		CombatAnchorUpgradeRuntime.STRONG_SECOND_INSTALL
	)))
	assert(is_equal_approx(
		anchors.get_effective_overload_duration(),
		anchors.balance.overload_duration + 3.0
	))

	anchors.toggle_anchor(2)
	assert(await _wait_until(
		func() -> bool: return anchors.is_path_available(2),
		180
	))
	var expected_second_duration: float = (
		anchors.balance.install_duration / (1.4 * 1.5)
	)
	assert(is_equal_approx(
		anchors.get_effective_install_duration(3),
		expected_second_duration
	))

	# Base emergency removal cannot touch an unserviced side.
	anchors.set_operator_assigned(AnchorRuntime.Side.RIGHT, false)
	anchors.request_remove_all()
	assert(anchors.is_path_available(2))

	assert(upgrades.apply_upgrade_effect(_flag(
		CombatAnchorUpgradeRuntime.INSTANT_REMOVE_ALL
	)))
	assert(anchors.is_instant_remove_all_enabled())
	anchors.request_remove_all()
	assert(anchors.get_anchor_state(2) == AnchorRuntime.State.STOWED)

	# An active install is atomic. Instant removal cancels queued work but waits
	# for the started install, which attaches and is immediately detached.
	anchors.set_operator_assigned(AnchorRuntime.Side.RIGHT, true)
	anchors.toggle_anchor(2)
	await physics_frame
	assert(anchors.get_anchor_state(2) == AnchorRuntime.State.INSTALLING)
	anchors.toggle_anchor(3)
	assert(anchors.get_anchor_state(3) == AnchorRuntime.State.QUEUED)
	anchors.set_operator_assigned(AnchorRuntime.Side.RIGHT, false)
	anchors.request_remove_all()
	assert(anchors.get_anchor_state(2) == AnchorRuntime.State.INSTALLING)
	assert(anchors.get_anchor_state(3) == AnchorRuntime.State.STOWED)
	assert(await _wait_until(
		func() -> bool:
			return anchors.get_anchor_state(2) == AnchorRuntime.State.STOWED,
		180
	))
	assert(not anchors.is_path_available(2))

	print("Combat anchor operation scenarios passed")
	quit()


func _scalar(target_id: StringName, value: float) -> UpgradeEffectDefinition:
	var effect := UpgradeEffectDefinition.new()
	effect.effect_type = UpgradeEffectDefinition.EffectType.DOMAIN_SCALAR
	effect.target_id = target_id
	effect.scalar_value = value
	return effect


func _flag(target_id: StringName) -> UpgradeEffectDefinition:
	var effect := UpgradeEffectDefinition.new()
	effect.effect_type = UpgradeEffectDefinition.EffectType.DOMAIN_FLAG
	effect.target_id = target_id
	return effect


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame: int in range(maximum_frames):
		if predicate.call():
			return true
		await physics_frame
	return bool(predicate.call())


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
