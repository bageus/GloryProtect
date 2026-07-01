extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_added_defender_leaves_portal_after_card_pause()
	await _test_new_defender_does_not_block_existing_pursuit()
	await _test_paused_portal_replacement_keeps_single_assignment()
	print("Defender spawn assignment scenarios passed")
	quit()


func _test_added_defender_leaves_portal_after_card_pause() -> void:
	var game: Node2D = await _create_game()
	var flow: GameFlowController = game.get_node("GameFlowController")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var roles := game.get_node(
		"World/Platform/CrewRoleManager"
	) as ShooterCrewRoleManagerPolished
	assert(roles != null)
	assert(crew.get_total_count() == 3)
	assert(roles.get_assignment_count() == 3)

	flow.begin_card_selection()
	assert(paused)
	var added: Defender = crew.add_defender()
	assert(added != null)
	var defender_id: int = added.defender_id
	var runtime: CrewAssignmentRuntime = roles.get_assignment(defender_id)
	assert(runtime != null)
	assert(roles.has_valid_living_assignment(defender_id))
	assert(roles.get_assignment_count() == crew.get_total_count())
	assert(runtime.state == CrewAssignmentRuntime.State.MOVING)
	assert(runtime.current_role == CrewRole.Id.FREE_FIGHTER)
	assert(runtime.target_role == CrewRole.Id.FREE_FIGHTER)
	assert(added.movement.is_moving())
	assert(is_equal_approx(
		added.position.x,
		crew.balance.replacement_door_local_x
	))
	var target_x: float = roles.get_role_target_x(
		CrewRole.Id.FREE_FIGHTER,
		defender_id
	)
	assert(not is_equal_approx(target_x, added.position.x))

	flow.finish_card_selection()
	await _wait_for_active_assignment(roles, defender_id)
	assert(is_equal_approx(added.position.x, target_x))
	assert(not added.movement.is_moving())
	assert(roles.get_assignment_count() == crew.get_total_count())
	await _destroy_game(game)


func _test_new_defender_does_not_block_existing_pursuit() -> void:
	var game: Node2D = await _create_game()
	var platform: PlatformController = game.get_node("World/Platform")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var roles := game.get_node(
		"World/Platform/CrewRoleManager"
	) as ShooterCrewRoleManagerPolished
	var spawn: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	assert(roles != null)

	roles.request_assignment(0, CrewRole.Id.FREE_FIGHTER)
	await _wait_for_active_assignment(roles, 0)
	var mover: Defender = crew.get_defender(0)
	for defender_id: int in [1, 2]:
		var defender: Defender = crew.get_defender(defender_id)
		defender.combat.set_physics_process(false)
		defender.shooter_combat.set_physics_process(false)
		defender.movement.set_physics_process(false)

	mover.teleport_to(-180.0)
	var enemy: BoardingEnemy = spawn.spawn_debug_on_platform(160.0, &"brute")
	assert(enemy != null)
	enemy.controller.set_physics_process(false)
	enemy.global_position.x = platform.global_position.x + 160.0
	var hit_count_before: int = mover.combat.get_completed_hit_count()
	await _wait_until_moving(mover)
	var mover_x_before_spawn: float = mover.position.x

	var newcomer: Defender = crew.add_defender()
	assert(newcomer != null)
	assert(newcomer.position.x > mover.position.x)
	assert(newcomer.position.x < enemy.position.x)
	newcomer.combat.set_physics_process(false)
	newcomer.shooter_combat.set_physics_process(false)

	await _wait_until_progress_or_hit(
		mover,
		mover_x_before_spawn,
		hit_count_before
	)
	assert(roles.has_valid_living_assignment(newcomer.defender_id))
	assert(roles.get_assignment_count() == crew.get_total_count())
	assert(
		mover.position.x > mover_x_before_spawn + 20.0
		or mover.combat.get_completed_hit_count() > hit_count_before
	)
	await _destroy_game(game)


func _test_paused_portal_replacement_keeps_single_assignment() -> void:
	var game: Node2D = await _create_game()
	var flow: GameFlowController = game.get_node("GameFlowController")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var roles := game.get_node(
		"World/Platform/CrewRoleManager"
	) as ShooterCrewRoleManagerPolished
	var replacements: CrewReplacementController = game.get_node(
		"CrewReplacementController"
	)
	var portal: PlatformVisualController = game.get_node(
		"World/Platform/PlatformVisualController"
	)
	assert(roles != null)
	replacements.instant_respawn_for_tests = true

	roles.request_assignment(0, CrewRole.Id.FREE_FIGHTER)
	await _wait_for_active_assignment(roles, 0)
	var previous: Defender = crew.get_defender(0)
	var previous_instance_id: int = previous.get_instance_id()
	previous.health.set_health(0)
	await _wait_until_portal_busy(portal)
	flow.toggle_manual_pause()
	assert(paused)
	for _frame: int in range(8):
		await process_frame
	assert(crew.get_defender(0).get_instance_id() == previous_instance_id)
	assert(replacements.is_replacement_pending(0))
	assert(roles.get_assignment_count() == crew.get_total_count())

	flow.toggle_manual_pause()
	assert(not paused)
	var replacement: Defender = await _wait_for_replacement(
		crew,
		0,
		previous_instance_id
	)
	assert(replacement != null)
	assert(roles.has_valid_living_assignment(0))
	assert(roles.get_assignment_count() == crew.get_total_count())
	await _wait_for_active_assignment(roles, 0)
	assert(not replacements.is_replacement_pending(0))
	await _destroy_game(game)


func _create_game() -> Node2D:
	paused = false
	var game := GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	flow.state = GameFlowController.RunState.RUNNING
	_disable_spawners(game)
	var roles: CrewRoleManager = game.get_node(
		"World/Platform/CrewRoleManager"
	)
	await _wait_for_assignment_count(roles, 3)
	return game


func _destroy_game(game: Node) -> void:
	paused = false
	game.queue_free()
	await process_frame
	await process_frame


func _wait_for_assignment_count(
	roles: CrewRoleManager,
	expected_count: int,
	max_frames: int = 120
) -> void:
	for _frame: int in range(max_frames):
		var found: int = 0
		for defender_id: int in range(expected_count):
			if roles.get_assignment(defender_id) != null:
				found += 1
		if found == expected_count:
			return
		await process_frame
	assert(false, "Crew assignments were not initialized")


func _wait_for_active_assignment(
	roles: CrewRoleManager,
	defender_id: int,
	max_frames: int = 240
) -> void:
	for _frame: int in range(max_frames):
		var runtime: CrewAssignmentRuntime = roles.get_assignment(defender_id)
		if (
			runtime != null
			and runtime.state == CrewAssignmentRuntime.State.ACTIVE
		):
			return
		await physics_frame
	assert(false, "Defender assignment did not become active")


func _wait_until_moving(
	defender: Defender,
	max_frames: int = 120
) -> void:
	for _frame: int in range(max_frames):
		if defender.movement.is_moving() and defender.position.x > -179.0:
			return
		await physics_frame
	assert(false, "Defender did not start pursuing the enemy")


func _wait_until_progress_or_hit(
	defender: Defender,
	starting_x: float,
	starting_hits: int,
	max_frames: int = 240
) -> void:
	for _frame: int in range(max_frames):
		if (
			defender.position.x > starting_x + 20.0
			or defender.combat.get_completed_hit_count() > starting_hits
		):
			return
		await physics_frame
	assert(false, "New defender permanently blocked pursuit")


func _wait_until_portal_busy(
	portal: PlatformVisualController,
	max_frames: int = 120
) -> void:
	for _frame: int in range(max_frames):
		if portal.is_portal_busy():
			return
		await physics_frame
	assert(false, "Portal spawn did not start")


func _wait_for_replacement(
	crew: CrewManager,
	defender_id: int,
	old_instance_id: int,
	max_frames: int = 240
) -> Defender:
	for _frame: int in range(max_frames):
		var current: Defender = crew.get_defender(defender_id)
		if (
			current != null
			and current.get_instance_id() != old_instance_id
			and current.health.is_alive()
		):
			return current
		await physics_frame
	return null


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
