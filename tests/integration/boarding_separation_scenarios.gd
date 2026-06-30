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
	await _test_ground_rerouting_after_anchor_changes(spawn, anchors, paths)

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
	for crew_member: Defender in crew.get_living_defenders():
		crew_member.melee.configure(1, 10.0, 1.0)

	roles.request_assignment(0, CrewRole.Id.FREE_FIGHTER)
	await _wait_until_assignment_active(roles, 0)

	var defender: Defender = crew.get_defender(0)
	var enemy: BoardingEnemy = spawn.spawn_debug_on_platform(80.0)
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


func _test_ground_rerouting_after_anchor_changes(
	spawn: BoardingSpawnDirector,
	anchors: AnchorSystem,
	paths: AnchorPathRegistry
) -> void:
	# Anchor 2 remains attached from the climb-spacing scenario. Attaching an
	# anchor on the opposite side reproduces the route split created by removing
	# and reinstalling anchors during a run.
	if not paths.is_path_available(0):
		anchors.toggle_anchor(0)
	await _wait_until_path_count(paths, 2)

	var left_path: AnchorPathSnapshot = null
	var right_path: AnchorPathSnapshot = null
	for path: AnchorPathSnapshot in paths.get_available_paths():
		if left_path == null or path.ground_point.x < left_path.ground_point.x:
			left_path = path
		if right_path == null or path.ground_point.x > right_path.ground_point.x:
			right_path = path
	assert(left_path != null and right_path != null)
	assert(left_path.anchor_id != right_path.anchor_id)

	var first: BoardingEnemy = spawn.spawn_debug_archetype(&"basic", -1)
	var second: BoardingEnemy = spawn.spawn_debug_archetype(&"basic", 1)
	assert(first != null and second != null)

	var midpoint: float = (
		left_path.ground_point.x + right_path.ground_point.x
	) * 0.5
	var minimum_gap: float = maxf(
		spawn.balance.ground_enemy_spacing,
		first.get_body_radius() + second.get_body_radius()
	)
	var initial_gap: float = minimum_gap + 2.0
	first.global_position = Vector2(
		midpoint - initial_gap * 0.5,
		left_path.ground_point.y
	)
	second.global_position = Vector2(
		midpoint + initial_gap * 0.5,
		right_path.ground_point.y
	)

	# Force the stale crossed assignments that existed before anchor paths were
	# re-evaluated. Without rerouting, both enemies walk into each other and stay
	# blocked at the minimum collision gap.
	first.controller.selected_anchor_id = right_path.anchor_id
	first.controller.state = BoardingEnemyController.State.RUNNING_TO_ANCHOR
	second.controller.selected_anchor_id = left_path.anchor_id
	second.controller.state = BoardingEnemyController.State.RUNNING_TO_ANCHOR
	var first_start_x: float = first.global_position.x
	var second_start_x: float = second.global_position.x

	await physics_frame
	assert(first.get_selected_anchor_id() == left_path.anchor_id)
	assert(second.get_selected_anchor_id() == right_path.anchor_id)

	await _wait_physics_frames(20)
	assert(first.global_position.x < first_start_x)
	assert(second.global_position.x > second_start_x)
	assert(
		second.global_position.x - first.global_position.x
		> initial_gap + 10.0
	)

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


func _wait_until_path_count(
	paths: AnchorPathRegistry,
	expected_count: int,
	max_frames: int = 240
) -> void:
	for _frame: int in range(max_frames):
		if paths.get_available_count() >= expected_count:
			return
		await physics_frame
	assert(false, "Expected anchor paths did not become available")


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
