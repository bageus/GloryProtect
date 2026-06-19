class_name DefenderCombatController
extends Node

var _configured: bool = false
var _defender: Defender
var _balance: BoardingBalance
var _game_flow: GameFlowController
var _roles: CrewRoleManager
var _enemies: BoardingEnemyRegistry
var _melee: MeleeAttackComponent


func configure(
	defender: Defender,
	balance: BoardingBalance,
	game_flow: GameFlowController,
	roles: CrewRoleManager,
	enemies: BoardingEnemyRegistry,
	melee: MeleeAttackComponent
) -> void:
	_defender = defender
	_balance = balance
	_game_flow = game_flow
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
	if _melee.is_attacking() or _defender.is_moving():
		return

	var assignment: CrewAssignmentRuntime = _roles.get_assignment(
		_defender.defender_id
	)
	if assignment == null:
		return
	if assignment.state != CrewAssignmentRuntime.State.ACTIVE:
		return
	if not _can_role_use_melee(assignment.current_role):
		return

	var max_target_distance: float = INF
	if assignment.current_role != CrewRole.Id.FREE_FIGHTER:
		max_target_distance = _balance.post_combat_radius

	var target: BoardingEnemy = _enemies.get_nearest_boarded_enemy(
		_defender.global_position,
		max_target_distance
	)
	if target == null:
		return

	var distance: float = absf(
		target.global_position.x - _defender.global_position.x
	)
	if distance <= _balance.defender_attack_range:
		_melee.try_start(target.health)


func is_action_active() -> bool:
	return _melee.is_attacking()


func cancel() -> void:
	_melee.cancel()


func _can_role_use_melee(role_id: int) -> bool:
	return (
		role_id == CrewRole.Id.FREE_FIGHTER
		or role_id == CrewRole.Id.LEFT_ANCHOR
		or role_id == CrewRole.Id.RIGHT_ANCHOR
	)
