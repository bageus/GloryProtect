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
	var inventory: BuildableInventory = game.get_node("BuildableInventory")
	var grid: BuildableGrid = game.get_node("World/BuildableGrid")
	var turrets: TurretSystem = game.get_node("World/TurretSystem")
	var roles: CrewRoleManager = game.get_node(
		"World/Platform/CrewRoleManager"
	)
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var spawn: BoardingSpawnDirector = game.get_node(
		"World/BoardingSpawnDirector"
	)
	var enemies: BoardingEnemyRegistry = game.get_node(
		"World/BoardingEnemyRegistry"
	)
	var economy: RunEconomy = game.get_node("RunEconomy")
	var statistics: RunStatistics = game.get_node("RunStatistics")
	var platform: PlatformController = game.get_node("World/Platform")

	game_flow.state = GameFlowController.RunState.RUNNING
	turrets.balance.turret_range = 150.0
	turrets.balance.turret_shot_windup = 0.12
	turrets.balance.turret_shot_cooldown = 0.0

	assert(grid.place(BuildableType.Id.TURRET, 3) == -1)
	assert(inventory.unlock(BuildableType.Id.TURRET) == 1)
	assert(inventory.unlock(BuildableType.Id.TURRET) == 2)
	var left_turret: int = grid.place(BuildableType.Id.TURRET, 3)
	var right_turret: int = grid.place(BuildableType.Id.TURRET, 14)
	assert(left_turret >= 0)
	assert(right_turret >= 0)
	await process_frame
	assert(turrets.has_turret(left_turret))
	assert(turrets.has_turret(right_turret))
	assert(roles.is_role_station_available(CrewRole.Id.TURRET, left_turret))
	assert(roles.is_role_station_available(CrewRole.Id.TURRET, right_turret))

	roles.request_assignment(0, CrewRole.Id.TURRET, left_turret)
	roles.request_assignment(1, CrewRole.Id.TURRET, right_turret)
	await _wait_for_role(roles, 0, CrewRole.Id.TURRET, left_turret, 300)
	await _wait_for_role(roles, 1, CrewRole.Id.TURRET, right_turret, 300)
	assert(roles.get_role_owner(CrewRole.Id.TURRET, left_turret) == 0)
	assert(roles.get_role_owner(CrewRole.Id.TURRET, right_turret) == 1)

	roles.request_assignment(2, CrewRole.Id.TURRET, left_turret)
	await process_frame
	var rejected: CrewAssignmentRuntime = roles.get_assignment(2)
	assert(rejected.current_role == CrewRole.Id.RIGHT_ANCHOR)

	var left_enemy: BoardingEnemy = spawn.spawn_debug_on_platform(-180.0)
	var right_enemy: BoardingEnemy = spawn.spawn_debug_on_platform(180.0)
	var left_enemy_id: int = left_enemy.enemy_id
	var right_enemy_id: int = right_enemy.enemy_id
	await _wait_for_firing(turrets, left_turret, left_enemy_id, 120)
	await _wait_for_firing(turrets, right_turret, right_enemy_id, 120)
	await _wait_for_enemy_removed(enemies, left_enemy_id, 120)
	await _wait_for_enemy_removed(enemies, right_enemy_id, 120)
	await process_frame
	assert(economy.get_coins() == 2)
	assert(statistics.get_physical_kills() == 2)

	var reassignment_enemy: BoardingEnemy = spawn.spawn_debug_on_platform(-180.0)
	reassignment_enemy.health.configure(2)
	var reassignment_enemy_id: int = reassignment_enemy.enemy_id
	await _wait_for_firing(
		turrets,
		left_turret,
		reassignment_enemy_id,
		120
	)
	roles.request_assignment(0, CrewRole.Id.FREE_FIGHTER)
	var waiting: CrewAssignmentRuntime = roles.get_assignment(0)
	assert(waiting.current_role == CrewRole.Id.TURRET)
	assert(waiting.current_station_id == left_turret)
	assert(waiting.state == CrewAssignmentRuntime.State.WAITING_FOR_ACTION)
	await _wait_for_health(reassignment_enemy, 1, 120)
	await _wait_for_role(roles, 0, CrewRole.Id.FREE_FIGHTER, -1, 180)
	assert(enemies.get_enemy(reassignment_enemy_id) != null)
	reassignment_enemy.kill(&"test_cleanup")
	await process_frame

	roles.request_assignment(0, CrewRole.Id.TURRET, left_turret)
	await _wait_for_role(roles, 0, CrewRole.Id.TURRET, left_turret, 300)
	turrets.balance.turret_shot_cooldown = 10.0
	var relocation_enemy: BoardingEnemy = spawn.spawn_debug_on_platform(-180.0)
	relocation_enemy.health.configure(2)
	var relocation_enemy_id: int = relocation_enemy.enemy_id
	await _wait_for_firing(turrets, left_turret, relocation_enemy_id, 120)
	assert(grid.move(left_turret, 4))
	await process_frame
	var relocation_wait: CrewAssignmentRuntime = roles.get_assignment(0)
	assert(relocation_wait.state == CrewAssignmentRuntime.State.WAITING_FOR_ACTION)
	await _wait_for_health(relocation_enemy, 1, 120)
	await _wait_for_role(roles, 0, CrewRole.Id.TURRET, left_turret, 300)
	assert(not turrets.is_firing(left_turret))
	assert(is_equal_approx(
		crew.get_defender(0).position.x,
		platform.get_cell_local_x(4)
	))

	assert(grid.demolish(left_turret))
	await process_frame
	assert(not turrets.has_turret(left_turret))
	assert(not roles.is_role_station_available(CrewRole.Id.TURRET, left_turret))
	var released: CrewAssignmentRuntime = roles.get_assignment(0)
	assert(released.current_role == CrewRole.Id.FREE_FIGHTER)
	assert(released.state == CrewAssignmentRuntime.State.ACTIVE)
	assert(inventory.get_unlocked_count(BuildableType.Id.TURRET) == 2)

	print("Turret scenarios passed")
	quit()


func _wait_for_role(
	roles: CrewRoleManager,
	defender_id: int,
	role_id: int,
	station_id: int,
	max_frames: int
) -> void:
	for _frame: int in range(max_frames):
		var assignment: CrewAssignmentRuntime = roles.get_assignment(defender_id)
		if (
			assignment != null
			and assignment.current_role == role_id
			and assignment.current_station_id == station_id
			and assignment.state == CrewAssignmentRuntime.State.ACTIVE
		):
			return
		await physics_frame
	assert(false, "Defender did not reach requested station role")


func _wait_for_firing(
	turrets: TurretSystem,
	buildable_id: int,
	enemy_id: int,
	max_frames: int
) -> void:
	for _frame: int in range(max_frames):
		if (
			turrets.is_firing(buildable_id)
			and turrets.get_target_enemy_id(buildable_id) == enemy_id
		):
			return
		await physics_frame
	assert(false, "Turret did not start firing at expected target")


func _wait_for_enemy_removed(
	enemies: BoardingEnemyRegistry,
	enemy_id: int,
	max_frames: int
) -> void:
	for _frame: int in range(max_frames):
		if enemies.get_enemy(enemy_id) == null:
			return
		await physics_frame
	assert(false, "Turret did not destroy expected enemy")


func _wait_for_health(
	enemy: BoardingEnemy,
	expected_health: int,
	max_frames: int
) -> void:
	for _frame: int in range(max_frames):
		if enemy.health.current_health == expected_health:
			return
		await physics_frame
	assert(false, "Enemy health did not reach expected value")
