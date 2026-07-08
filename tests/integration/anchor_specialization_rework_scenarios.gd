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

	var catalog: UpgradeCatalog = game.get_node("UpgradeSystem").catalog
	var combat: CombatAnchorSystem = game.get_node("World/CombatAnchorSystem")
	var anchors: CombatAnchorHostSystem = game.get_node("World/AnchorSystem")
	var visual: CombatAnchorVisualController = anchors.get_node(
		"AnchorVisualController"
	) as CombatAnchorVisualController
	var audio: GameAudioController = game.get_node("GameAudioController")
	assert(catalog != null)
	assert(combat != null)
	assert(visual != null)
	assert(audio != null)

	assert(is_equal_approx(combat.get_endpoint_pulse_radius_for_tests(), 240.0))
	assert(is_equal_approx(combat.get_drop_pulse_interval_for_tests(), 2.0))
	assert(is_equal_approx(combat.get_trap_explosion_radius_for_tests(), 240.0))
	assert(is_equal_approx(combat.get_trap_knockback_distance_for_tests(), 300.0))
	assert(audio.get_loaded_sound_ids().has(GameAudioController.SOUND_BOOM_WINCH))
	assert(visual.get_winch_asset_id_for_tests() == &"base")

	assert(combat.apply_upgrade_effect(
		catalog.get_definition(CombatAnchorUpgradeRuntime.STRONG).effect
	))
	await process_frame
	assert(visual.get_winch_asset_id_for_tests() == &"strong")
	assert(combat.apply_upgrade_effect(
		catalog.get_definition(CombatAnchorUpgradeRuntime.STRONG_SECOND_INSTALL).effect
	))
	assert(combat.is_pair_install_fall_chance_enabled_for_tests())
	combat.reset_upgrade_runtime()
	await process_frame
	assert(visual.get_winch_asset_id_for_tests() == &"base")

	assert(combat.apply_upgrade_effect(
		catalog.get_definition(CombatAnchorUpgradeRuntime.ELECTRIC).effect
	))
	await process_frame
	assert(visual.get_winch_asset_id_for_tests() == &"specialization_2")
	assert(combat.apply_upgrade_effect(
		catalog.get_definition(CombatAnchorUpgradeRuntime.ELECTRIC_DROP).effect
	))
	assert(is_equal_approx(combat.get_drop_pulse_interval_for_tests(), 2.0))
	combat.reset_upgrade_runtime()
	await process_frame

	assert(combat.apply_upgrade_effect(
		catalog.get_definition(CombatAnchorUpgradeRuntime.TRAP).effect
	))
	await process_frame
	assert(visual.get_winch_asset_id_for_tests() == &"specialization_2")
	audio.set_audio_enabled(true)
	assert(audio.get_trigger_count(GameAudioController.SOUND_BOOM_WINCH) == 0)
	combat.trap_triggered.emit(
		0,
		Vector2.ZERO,
		240.0,
		0,
		&"anchor_trap_attach"
	)
	await process_frame
	assert(audio.get_trigger_count(GameAudioController.SOUND_BOOM_WINCH) == 1)
	combat.trap_triggered.emit(
		0,
		Vector2.ZERO,
		240.0,
		0,
		&"anchor_trap_remove"
	)
	await process_frame
	assert(audio.get_trigger_count(GameAudioController.SOUND_BOOM_WINCH) == 2)
	combat.trap_triggered.emit(
		0,
		Vector2.ZERO,
		240.0,
		0,
		&"debug_non_trap"
	)
	await process_frame
	assert(audio.get_trigger_count(GameAudioController.SOUND_BOOM_WINCH) == 2)

	print("Anchor specialization rework scenarios passed")
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
