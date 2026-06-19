extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root.tscn")


func _init() -> void:
	call_deferred("_run_scenario")


func _run_scenario() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var game_flow: GameFlowController = game.get_node("GameFlowController")
	var wind: WindSystem = game.get_node("WindSystem")
	var platform: PlatformController = game.get_node("World/Platform")
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

	roles.request_assignment(0, CrewRole.Id.FREE_FIGHTER)
	await _wait_until_assignment_active(roles, 0)

	var fighter: Defender = crew.get_defender(0)
	var starting_x: float = fighter.position.x
	var enemy: BoardingEnemy = spawn.spawn_debug_on_platform(120.0)
	assert(enemy != null)
	assert(enemy.health.is_alive())

	await _wait_physics_frames(10)
	assert(fighter.position.x > starting_x)
	assert(fighter.is_moving() or fighter.is_combat_action_active())

	await _wait_until_enemy_dead(enemy, 120)
	assert(not is_instance_valid(enemy) or not enemy.health.is_alive())

	print("Free fighter pursuit scenario passed")
	quit()


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
	assert(false, "Defender did not become active free fighter")


func _wait_until_enemy_dead(
	enemy: BoardingEnemy,
	max_frames: int
) -> void:
	for _frame: int in range(max_frames):
		if not is_instance_valid(enemy) or not enemy.health.is_alive():
			return
		await physics_frame
	assert(false, "Free fighter did not defeat the pursued enemy")


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await physics_frame
