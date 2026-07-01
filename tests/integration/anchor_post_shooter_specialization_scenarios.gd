extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")
const ATTACK_TICK: float = 25.0


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

	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var roles: ShooterCrewRoleManagerPolished = game.get_node(
		"World/Platform/CrewRoleManager"
	)
	var spawn: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	var flying_spawn: FlyingEnemySpawnDirector = game.get_node(
		"World/FlyingEnemySpawnDirector"
	)
	var anchors: AnchorSystem = game.get_node("World/AnchorSystem")
	var platform: PlatformController = game.get_node("World/Platform")
	var orbs: GroundOrbRegistry = game.get_node("World/GroundOrbRegistry")

	await _test_anchor_hunter_on_post(
		crew,
		roles,
		spawn,
		CrewRole.Id.LEFT_ANCHOR,
		1
	)
	await _test_anchor_hunter_on_post(
		crew,
		roles,
		spawn,
		CrewRole.Id.RIGHT_ANCHOR,
		2
	)
	await _test_air_hunter_on_post(
		crew,
		roles,
		flying_spawn,
		CrewRole.Id.LEFT_ANCHOR,
		1
	)
	await _test_air_hunter_on_post(
		crew,
		roles,
		flying_spawn,
		CrewRole.Id.RIGHT_ANCHOR,
		2
	)
	await _test_anchor_operation_blocks_new_shot(
		crew,
		roles,
		spawn,
		anchors,
		platform,
		orbs
	)

	print("Anchor post shooter specialization scenarios passed")
	quit()


func _test_anchor_hunter_on_post(
	crew: CrewManager,
	roles: ShooterCrewRoleManagerPolished,
	spawn: BoardingSpawnDirector,
	anchor_role: int,
	defender_id: int
) -> void:
	_prepare_shooter_role(
		crew,
		roles,
		defender_id,
		anchor_role,
		&"shooter_specialization_anchor_hunter",
		&"shooter_anchor_knockdown_fifth"
	)
	var defender: Defender = crew.get_defender(defender_id)
	var target: BoardingEnemy = spawn.spawn_debug_archetype(&"brute", 1)
	assert(target != null)
	target.controller.set_physics_process(false)
	target.controller.state = BoardingEnemyController.State.CLIMBING
	target.global_position = defender.global_position + Vector2(80.0, 0.0)
	defender.shooter_combat.set("_completed_volleys", 4)

	_start_shot(defender, target)
	_finish_ranged_sequence(defender)
	assert(not target.health.is_alive())
	assert(defender.shooter_combat.get_completed_volley_count() == 5)
	_cleanup_enemy(target)
	await process_frame


func _test_air_hunter_on_post(
	crew: CrewManager,
	roles: ShooterCrewRoleManagerPolished,
	flying_spawn: FlyingEnemySpawnDirector,
	anchor_role: int,
	defender_id: int
) -> void:
	_prepare_shooter_role(
		crew,
		roles,
		defender_id,
		anchor_role,
		&"shooter_specialization_air_hunter"
	)
	var defender: Defender = crew.get_defender(defender_id)
	var target: BoardingEnemy = flying_spawn.spawn_now(1)
	assert(target != null)
	target.behavior.set_physics_process(false)
	target.global_position = defender.global_position + Vector2(80.0, -12.0)
	var health_before: int = target.health.current_health

	_start_shot(defender, target)
	_finish_ranged_sequence(defender)
	assert(target.health.current_health < health_before or not target.health.is_alive())
	_cleanup_enemy(target)
	await process_frame


func _test_anchor_operation_blocks_new_shot(
	crew: CrewManager,
	roles: ShooterCrewRoleManagerPolished,
	spawn: BoardingSpawnDirector,
	anchors: AnchorSystem,
	platform: PlatformController,
	orbs: GroundOrbRegistry
) -> void:
	_prepare_shooter_role(
		crew,
		roles,
		1,
		CrewRole.Id.LEFT_ANCHOR,
		&"shooter_specialization_anchor_hunter"
	)
	var defender: Defender = crew.get_defender(1)
	var target: BoardingEnemy = spawn.spawn_debug_archetype(&"brute", 1)
	assert(target != null)
	target.controller.set_physics_process(false)
	target.controller.state = BoardingEnemyController.State.CLIMBING
	target.global_position = defender.global_position + Vector2(80.0, 0.0)

	platform.position.x = orbs.get_world_x(2)
	anchors.toggle_anchor(0)
	assert(anchors.is_operator_busy(AnchorRuntime.Side.LEFT))
	defender.shooter_combat._physics_process(0.1)
	assert(defender.shooter_combat.get_locked_enemy() == null)
	assert(defender.ranged.phase == RangedAttackComponent.Phase.READY)

	anchors._physics_process(anchors.balance.install_duration + 0.1)
	assert(not anchors.is_operator_busy(AnchorRuntime.Side.LEFT))
	_start_shot(defender, target)
	_finish_ranged_sequence(defender)
	assert(defender.shooter_combat.get_completed_bolt_count() > 0)
	_cleanup_enemy(target)
	anchors.request_remove_all()
	await process_frame


func _prepare_shooter_role(
	crew: CrewManager,
	roles: ShooterCrewRoleManagerPolished,
	defender_id: int,
	anchor_role: int,
	specialization_flag: StringName,
	extra_flag: StringName = &""
) -> void:
	crew.reset_run_modifiers()
	assert(crew.apply_shooter_flag(&"shooter_role_unlocked"))
	assert(crew.apply_shooter_flag(specialization_flag))
	if extra_flag != &"":
		assert(crew.apply_shooter_flag(extra_flag))
	assert(roles.set_combat_role(defender_id, CrewRole.Id.SHOOTER))
	var assignment: CrewAssignmentRuntime = roles.get_assignment(defender_id)
	assert(assignment != null)
	assert(assignment.current_role == anchor_role)
	assert(assignment.combat_role == CrewRole.Id.SHOOTER)
	assert(assignment.state == CrewAssignmentRuntime.State.ACTIVE)


func _start_shot(defender: Defender, target: BoardingEnemy) -> void:
	assert(defender.ranged.phase == RangedAttackComponent.Phase.READY)
	defender.shooter_combat._physics_process(0.1)
	assert(defender.shooter_combat.get_locked_enemy() == target)
	assert(defender.ranged.phase == RangedAttackComponent.Phase.WINDUP)


func _finish_ranged_sequence(defender: Defender) -> void:
	for _index: int in range(12):
		defender.ranged.tick(ATTACK_TICK)
		if defender.ranged.phase == RangedAttackComponent.Phase.READY:
			return
	assert(false)


func _cleanup_enemy(enemy: BoardingEnemy) -> void:
	if enemy != null and is_instance_valid(enemy) and enemy.health.is_alive():
		enemy.kill(&"test_cleanup")


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
