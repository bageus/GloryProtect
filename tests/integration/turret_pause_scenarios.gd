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
	var inventory: BuildableInventory = game.get_node("BuildableInventory")
	var grid: BuildableGrid = game.get_node("World/BuildableGrid")
	var turrets: TurretSystem = game.get_node("World/TurretSystem")
	var roles: CrewRoleManager = game.get_node(
		"World/Platform/CrewRoleManager"
	)
	var spawn: BoardingSpawnDirector = game.get_node(
		"World/BoardingSpawnDirector"
	)
	var enemies: BoardingEnemyRegistry = game.get_node(
		"World/BoardingEnemyRegistry"
	)

	game_flow.state = GameFlowController.RunState.RUNNING
	turrets.balance.turret_range = 1000.0
	turrets.balance.turret_shot_windup = 0.5
	turrets.balance.turret_shot_cooldown = 0.5

	assert(inventory.unlock(BuildableType.Id.TURRET) == 1)
	var turret_id: int = grid.place(BuildableType.Id.TURRET, 4)
	assert(turret_id >= 0)
	await process_frame
	roles.request_assignment(0, CrewRole.Id.TURRET, turret_id)
	await _wait_for_role(roles, 0, turret_id, 300)

	var enemy: BoardingEnemy = spawn.spawn_debug_on_platform(80.0)
	enemy.health.configure(2)
	var enemy_id: int = enemy.enemy_id
	await _wait_for_firing(turrets, turret_id, 120)

	var shot_before_pause: float = turrets.get_shot_remaining(turret_id)
	game_flow.begin_card_selection()
	await _wait_process_frames(8)
	assert(is_equal_approx(
		turrets.get_shot_remaining(turret_id),
		shot_before_pause
	))
	assert(enemy.health.current_health == 2)
	game_flow.finish_card_selection()
	await _wait_for_health(enemy, 1, 180)

	var cooldown_before_pause: float = turrets.get_cooldown_remaining(turret_id)
	assert(cooldown_before_pause > 0.0)
	game_flow.begin_card_selection()
	await _wait_process_frames(8)
	assert(is_equal_approx(
		turrets.get_cooldown_remaining(turret_id),
		cooldown_before_pause
	))
	game_flow.finish_card_selection()
	await _wait_for_enemy_removed(enemies, enemy_id, 240)

	print("Turret pause scenarios passed")
	quit()


func _wait_for_role(
	roles: CrewRoleManager,
	defender_id: int,
	turret_id: int,
	max_frames: int
) -> void:
	for _frame: int in range(max_frames):
		var assignment: CrewAssignmentRuntime = roles.get_assignment(defender_id)
		if (
			assignment != null
			and assignment.current_role == CrewRole.Id.TURRET
			and assignment.current_station_id == turret_id
			and assignment.state == CrewAssignmentRuntime.State.ACTIVE
		):
			return
		await physics_frame
	assert(false, "Operator did not reach turret")


func _wait_for_firing(
	turrets: TurretSystem,
	turret_id: int,
	max_frames: int
) -> void:
	for _frame: int in range(max_frames):
		if turrets.is_firing(turret_id):
			return
		await physics_frame
	assert(false, "Turret did not start firing")


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


func _wait_for_enemy_removed(
	enemies: BoardingEnemyRegistry,
	enemy_id: int,
	max_frames: int
) -> void:
	for _frame: int in range(max_frames):
		if enemies.get_enemy(enemy_id) == null:
			return
		await physics_frame
	assert(false, "Enemy was not removed")


func _wait_process_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await process_frame
