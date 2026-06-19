class_name DefenderCombatController
extends Node

var _configured: bool = false
var _defender: Defender
var _balance: BoardingBalance
var _game_flow: GameFlowController
var _platform: PlatformController
var _roles: CrewRoleManager
var _enemies: BoardingEnemyRegistry
var _melee: MeleeAttackComponent


func configure(
	defender: Defender,
	balance: BoardingBalance,
	game_flow: GameFlowController,
	platform: PlatformController,
	roles: CrewRoleManager,
	enemies: BoardingEnemyRegistry,
	melee: MeleeAttackComponent
) -> void:
	_defender = defender
	_balance = balance
	_game_flow = game_flow
	_platform = platform
	_roles = roles
	_enemies = enemies
	_melee = melee
	_configured = true


func _physics_process(delta: float) -> void:
	if not _configured:
		return
	if not _game_flow.is_world_simulation_active():
		return
	if not _defender.health.is_alive():
		return

	_melee.tick(delta)
	var assignment: CrewAssignmentRuntime = _roles.get_assignment(
		_defender.defender_id
	)
	if assignment == null:
		return

	if _melee.is_attacking():
		_defender.movement.pause()
		return

	if assignment.state == CrewAssignmentRuntime.State.MOVING:
		_update_moving_assignment_combat()
		return
	if (
		assignment.state != CrewAssignmentRuntime.State.ACTIVE
		and assignment.state != CrewAssignmentRuntime.State.WAITING_FOR_ACTION
	):
		return
	if not _can_role_use_melee(assignment.current_role):
		return

	var max_target_distance: float = _get_target_search_distance(assignment)
	var target: BoardingEnemy = _enemies.get_nearest_boarded_enemy(
		_defender.global_position,
		max_target_distance
	)
	if target == null:
		_stop_free_fighter_without_target(assignment)
		return

	var distance: float = absf(
		target.global_position.x - _defender.global_position.x
	)
	if distance <= _balance.defender_attack_range:
		_defender.movement.pause()
		_melee.try_start(target.health)
		return

	if (
		assignment.state == CrewAssignmentRuntime.State.ACTIVE
		and assignment.current_role == CrewRole.Id.FREE_FIGHTER
	):
		var target_local_x: float = (
			target.global_position.x - _platform.global_position.x
		)
		_defender.movement.move_to(target_local_x)


func is_action_active() -> bool:
	if not _configured or _melee == null:
		return false
	if _melee.is_attacking():
		return true

	var assignment: CrewAssignmentRuntime = _roles.get_assignment(
		_defender.defender_id
	)
	if assignment == null or not _can_role_use_melee(assignment.current_role):
		return false

	return _enemies.get_nearest_boarded_enemy(
		_defender.global_position,
		_balance.defender_attack_range
	) != null


func cancel() -> void:
	if _melee != null:
		_melee.cancel()


func _update_moving_assignment_combat() -> void:
	var target: BoardingEnemy = _enemies.get_nearest_boarded_enemy(
		_defender.global_position,
		_balance.defender_attack_range
	)
	if target == null:
		_defender.movement.resume()
		return

	_defender.movement.pause()
	_melee.try_start(target.health)


func _get_target_search_distance(
	assignment: CrewAssignmentRuntime
) -> float:
	if assignment.state == CrewAssignmentRuntime.State.WAITING_FOR_ACTION:
		return _balance.defender_attack_range
	if assignment.current_role == CrewRole.Id.FREE_FIGHTER:
		return INF
	return _balance.post_combat_radius


func _stop_free_fighter_without_target(
	assignment: CrewAssignmentRuntime
) -> void:
	if (
		assignment.state == CrewAssignmentRuntime.State.ACTIVE
		and assignment.current_role == CrewRole.Id.FREE_FIGHTER
	):
		_defender.movement.stop()


func _can_role_use_melee(role_id: int) -> bool:
	return (
		role_id == CrewRole.Id.FREE_FIGHTER
		or role_id == CrewRole.Id.LEFT_ANCHOR
		or role_id == CrewRole.Id.RIGHT_ANCHOR
	)
