extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var game_flow: GameFlowController = game.get_node("GameFlowController")
	var wind: WindSystem = game.get_node("WindSystem")
	var platform: PlatformController = game.get_node("World/Platform")
	var anchors: AnchorSystem = game.get_node("World/AnchorSystem")
	var paths: AnchorPathRegistry = game.get_node("World/AnchorPathRegistry")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var roles: CrewRoleManager = game.get_node(
		"World/Platform/CrewRoleManager"
	)
	var spawn: BoardingSpawnDirector = game.get_node(
		"World/BoardingSpawnDirector"
	)

	game_flow.state = GameFlowController.RunState.RUNNING
	wind.balance.level_forces = PackedFloat32Array([0.0, 0.0, 0.0])
	wind.balance.fluctuation_force = 0.0
	wind.set_debug_state(1, 1)
	platform.position.x = 0.0
	platform.horizontal_velocity = 0.0
	spawn.balance.spawn_interval = 999.0

	await _test_platform_enemy_separation(spawn)
	await _test_enemy_defender_blocking(spawn, crew, roles)
	await _test_climb_spacing(spawn, anchors, paths)

	print("Boarding separation scenarios passed")
	quit()


func _test_platform_enemy_separation(
	spawn: BoardingSpawnDirector
) -> void:
	var first: BoardingEnemy = spawn.spawn_debug_on_platform(160.0)
	var second: BoardingEnemy = spawn.spawn_debug_on_platform(160.0)
	first.melee.configure(1, 10.0, 1.0)
	second.melee.configure(1, 10.0, 1.0)
	await _wait_physics_frames(20)

	var distance: float = absf(
		first.controller.get_platform_local_x()
		- second.controller.get_platform_local_x()
	)
	assert(distance >= spawn.balance.platform_enemy_spacing - 0.5)

	first.kill(&"test_cleanup")
	second.kill(&"test_cleanup")
	await _wait_physics_frames(2)


func _test_enemy_defender_blocking(
	spawn: BoardingSpawnDirector,
	crew: CrewManager,
	roles: CrewRoleManager
) -> void:
	roles.request_assignment(0, CrewRole.Id.FREE_FIGHTER)
	await _wait_until_assignment_active(roles, 0)

	var defender: Defender = crew.get_defender(0)
	defender.melee.configure(1, 10.0, 1.0)
	var enemy: BoardingEnemy = spawn.spawn_debug_on_platform(140.0)
	enemy.melee.configure(1, 10.0, 1.0)
	await _wait_physics_frames(90)

	var enemy_x: float = enemy.controller.get_platform_local_x()
	var minimum_gap: float = (
		spawn.balance.enemy_body_radius
		+ crew.balance.defender_body_radius
	)
	assert(enemy_x >= defender.position.x)
	assert(absf(enemy_x - defender.position.x) >= minimum_gap - 0.5)

	enemy.kill(&"test_cleanup")
	await _wait_physics_frames(2)


func _test_climb_spacing(
	spawn: BoardingSpawnDirector,
	anchors: AnchorSystem,
	paths: AnchorPathRegistry
) -> void:
	anchors.toggle_anchor(2)
	await _wait_until_path_available(paths)
	var path: AnchorPathSnapshot = paths.get_available_paths()[0]
	var rope_length: float = maxf(
		1.0,
		path.ground_point.distance_to(path.platform_point)
	)

	var first: BoardingEnemy = spawn.spawn_now()
	var second: BoardingEnemy = spawn.spawn_now()
	assert(first != null and second != null)
	first.global_position = path.ground_point
	second.global_position = path.ground_point + Vector2(
		spawn.balance.ground_enemy_spacing,
		0.0
	)

	await _wait_until_both_climbing(first, second)
	var progress_distance: float = absf(
		first.controller.get_climb_progress()
		- second.controller.get_climb_progress()
	) * rope_length
	assert(progress_distance >= spawn.balance.climb_enemy_spacing - 1.0)

	first.kill(&"test_cleanup")
	second.kill(&"test_cleanup")
	await _wait_physics_frames(2)


func _wait_until_assignment_active(
	roles: CrewRoleManager,
	defender_id: int,
	max_frames: int = 180
) -> void:
	for _frame: int in range(max_frames):
		var assignment: CrewAssignmentRuntime = roles.get_assignment(defender_id)
		if assignment.state == CrewAssignmentRuntime.State.ACTIVE:
			return
		await physics_frame
	assert(false, "Defender did not reach the requested role")


func _wait_until_path_available(
	paths: AnchorPathRegistry,
	max_frames: int = 180
) -> void:
	for _frame: int in range(max_frames):
		if paths.has_available_paths():
			return
		await physics_frame
	assert(false, "Anchor path did not become available")


func _wait_until_both_climbing(
	first: BoardingEnemy,
	second: BoardingEnemy,
	max_frames: int = 180
) -> void:
	for _frame: int in range(max_frames):
		if (
			first.get_state() == BoardingEnemyController.State.CLIMBING
			and second.get_state() == BoardingEnemyController.State.CLIMBING
		):
			return
		await physics_frame
	assert(false, "Enemies did not enter the same rope queue")


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await physics_frame
