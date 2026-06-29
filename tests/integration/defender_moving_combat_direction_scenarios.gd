extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(DefenderCombatController.is_local_x_on_forward_path(0.0, 160.0, 24.0))
	assert(not DefenderCombatController.is_local_x_on_forward_path(0.0, 160.0, -24.0))
	assert(DefenderCombatController.is_local_x_on_forward_path(0.0, -160.0, -24.0))
	assert(not DefenderCombatController.is_local_x_on_forward_path(0.0, -160.0, 24.0))

	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	flow.state = GameFlowController.RunState.RUNNING
	_disable_spawners(game)

	var platform: PlatformController = game.get_node("World/Platform")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var roles: CrewRoleManager = game.get_node("World/Platform/CrewRoleManager")
	var spawn: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	await _wait_for_assignments(roles, 60)

	var mover: Defender = crew.get_defender(0)
	var engaged_defender: Defender = crew.get_defender(1)
	var runtime: CrewAssignmentRuntime = roles.get_assignment(mover.defender_id)
	assert(runtime != null)
	engaged_defender.combat.set_physics_process(false)
	engaged_defender.shooter_combat.set_physics_process(false)
	engaged_defender.movement.set_physics_process(false)

	mover.combat.cancel()
	mover.teleport_to(0.0)
	mover.move_to(160.0)
	runtime.state = CrewAssignmentRuntime.State.MOVING
	var rear_enemy: BoardingEnemy = spawn.spawn_debug_on_platform(-60.0, &"basic")
	assert(rear_enemy != null)
	rear_enemy.controller.set_physics_process(false)
	rear_enemy.global_position.x = platform.global_position.x - 28.0
	engaged_defender.teleport_to(-28.0)
	assert(rear_enemy.melee.try_start(engaged_defender.health))
	await _wait_physics_frames(8)
	assert(not mover.movement.is_paused())
	assert(mover.position.x > 1.0)

	rear_enemy.kill(&"test_cleanup")
	await _wait_physics_frames(3)
	mover.combat.cancel()
	mover.teleport_to(0.0)
	mover.move_to(160.0)
	runtime.state = CrewAssignmentRuntime.State.MOVING
	engaged_defender.teleport_to(-120.0)
	var forward_enemy: BoardingEnemy = spawn.spawn_debug_on_platform(60.0, &"basic")
	assert(forward_enemy != null)
	forward_enemy.controller.set_physics_process(false)
	forward_enemy.global_position.x = platform.global_position.x + 28.0
	await _wait_physics_frames(3)
	assert(mover.movement.is_paused())
	assert(mover.melee.is_attacking())

	print("Defender moving combat direction scenarios passed")
	quit()


func _wait_for_assignments(
	roles: CrewRoleManager,
	max_frames: int
) -> void:
	for _frame: int in range(max_frames):
		if roles.get_assignment(0) != null and roles.get_assignment(1) != null:
			return
		await process_frame
	assert(false, "Crew assignments were not initialized")


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await physics_frame


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
