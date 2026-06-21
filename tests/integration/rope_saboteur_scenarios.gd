extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	await _test_explosion_damages_only_target_rope_and_pauses()
	await _test_closed_target_retargets_and_combat_kill_is_rewarded()
	print("Rope saboteur integration scenarios passed")
	quit()


func _test_explosion_damages_only_target_rope_and_pauses() -> void:
	var game: Node = GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame

	var game_flow: GameFlowController = game.get_node("GameFlowController")
	var economy: RunEconomy = game.get_node("RunEconomy")
	var shield: ShieldSystem = game.get_node("ShieldSystem")
	var wind: WindSystem = game.get_node("WindSystem")
	var platform: PlatformController = game.get_node("World/Platform")
	var anchors: AnchorSystem = game.get_node("World/AnchorSystem")
	var director: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	var registry: BoardingEnemyRegistry = game.get_node("World/BoardingEnemyRegistry")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")

	director.set_physics_process(false)
	_configure_stable_world(game_flow, wind, platform)
	assert(director.spawn_now() == null)
	await _install_anchor(anchors, 2)

	var starting_shield: Array[float] = []
	for section_id: int in range(shield.get_section_count()):
		starting_shield.append(shield.get_health(section_id))
	var starting_crew: Array[int] = []
	for defender: Defender in crew.get_all_defenders():
		starting_crew.append(defender.health.current_health)
	var starting_coins: int = economy.get_coins()
	var starting_platform_position: Vector2 = platform.position

	var saboteur: BoardingEnemy = director.spawn_debug_archetype(
		&"rope_saboteur",
		1
	)
	assert(saboteur != null)
	assert(saboteur.controller is RopeSaboteurController)
	assert(saboteur.is_grounded_for_limit())
	assert(not saboteur.is_climbing())
	assert(not saboteur.is_on_platform())
	var behavior: RopeSaboteurController = saboteur.controller as RopeSaboteurController
	assert(await _wait_until(func() -> bool: return behavior.is_arming(), 600))
	var target_anchor_id: int = behavior.get_selected_anchor_id()
	assert(target_anchor_id >= 0)
	var target_before: AnchorRopeSnapshot = anchors.get_rope_snapshot(
		target_anchor_id
	)
	var progress_before_pause: float = behavior.get_arming_progress()

	game_flow.state = GameFlowController.RunState.MANUAL_PAUSE
	await _wait_physics_frames(45)
	assert(is_equal_approx(
		behavior.get_arming_progress(),
		progress_before_pause
	))
	game_flow.state = GameFlowController.RunState.RUNNING

	assert(await _wait_until(
		func() -> bool:
			return registry.get_archetype_count(&"rope_saboteur") == 0,
		240
	))
	var target_after: AnchorRopeSnapshot = anchors.get_rope_snapshot(
		target_anchor_id
	)
	var definition: RopeSaboteurArchetype = saboteur.archetype as RopeSaboteurArchetype
	assert(is_equal_approx(
		target_after.current_durability,
		target_before.current_durability - definition.rope_damage
	))
	for snapshot: AnchorRopeSnapshot in anchors.get_all_rope_snapshots():
		if snapshot.anchor_id == target_anchor_id:
			continue
		assert(is_equal_approx(
			snapshot.current_durability,
			snapshot.maximum_durability
		))
	assert(anchors.is_path_available(target_anchor_id))
	assert(economy.get_coins() == starting_coins)
	assert(platform.position.is_equal_approx(starting_platform_position))
	for section_id: int in range(shield.get_section_count()):
		assert(is_equal_approx(
			shield.get_health(section_id),
			starting_shield[section_id]
		))
	var defenders: Array[Defender] = crew.get_all_defenders()
	for defender_id: int in range(defenders.size()):
		assert(defenders[defender_id].health.current_health == starting_crew[defender_id])

	game.queue_free()
	await process_frame


func _test_closed_target_retargets_and_combat_kill_is_rewarded() -> void:
	var game: Node = GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame

	var game_flow: GameFlowController = game.get_node("GameFlowController")
	var economy: RunEconomy = game.get_node("RunEconomy")
	var wind: WindSystem = game.get_node("WindSystem")
	var platform: PlatformController = game.get_node("World/Platform")
	var anchors: AnchorSystem = game.get_node("World/AnchorSystem")
	var director: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	var registry: BoardingEnemyRegistry = game.get_node("World/BoardingEnemyRegistry")

	director.set_physics_process(false)
	_configure_stable_world(game_flow, wind, platform)
	await _install_anchor(anchors, 2)
	await _install_anchor(anchors, 3)

	var saboteur: BoardingEnemy = director.spawn_debug_archetype(
		&"rope_saboteur",
		1
	)
	assert(saboteur != null)
	var behavior: RopeSaboteurController = saboteur.controller as RopeSaboteurController
	assert(await _wait_until(
		func() -> bool: return behavior.get_selected_anchor_id() >= 0,
		60
	))
	var first_target: int = behavior.get_selected_anchor_id()
	anchors.toggle_anchor(first_target)
	assert(await _wait_until(
		func() -> bool:
			return (
				behavior.get_selected_anchor_id() >= 0
				and behavior.get_selected_anchor_id() != first_target
			),
		240
	))
	var second_target: int = behavior.get_selected_anchor_id()
	assert(anchors.is_path_available(second_target))

	var durability_before: Array[float] = []
	for snapshot: AnchorRopeSnapshot in anchors.get_all_rope_snapshots():
		durability_before.append(snapshot.current_durability)
	var starting_coins: int = economy.get_coins()
	saboteur.health.apply_damage(1)
	await process_frame
	assert(registry.get_archetype_count(&"rope_saboteur") == 0)
	assert(economy.get_coins() == starting_coins + 1)
	for snapshot: AnchorRopeSnapshot in anchors.get_all_rope_snapshots():
		assert(is_equal_approx(
			snapshot.current_durability,
			durability_before[snapshot.anchor_id]
		))

	game.queue_free()
	await process_frame


func _configure_stable_world(
	game_flow: GameFlowController,
	wind: WindSystem,
	platform: PlatformController
) -> void:
	game_flow.state = GameFlowController.RunState.RUNNING
	wind.balance.level_forces = PackedFloat32Array([0.0, 0.0, 0.0])
	wind.balance.fluctuation_force = 0.0
	wind.set_debug_state(1, 1)
	platform.position.x = 0.0
	platform.horizontal_velocity = 0.0


func _install_anchor(anchors: AnchorSystem, anchor_id: int) -> void:
	anchors.toggle_anchor(anchor_id)
	await _wait_physics_frames(120)
	assert(anchors.is_path_available(anchor_id))


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame: int in range(maximum_frames):
		if predicate.call():
			return true
		await physics_frame
	return predicate.call()


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await physics_frame
