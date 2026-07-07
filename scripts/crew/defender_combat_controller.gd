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
var _locked_enemy: BoardingEnemy
var _retaliation_target: BoardingEnemy
var _completed_hits: int = 0
var _double_attack_follow_up_active: bool = false
var _resolver := MeleeDefenderCombatResolver.new()


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
	if not _melee.attack_landed.is_connected(_on_attack_landed):
		_melee.attack_landed.connect(_on_attack_landed)
	if not _defender.health.damage_received.is_connected(_on_damage_received):
		_defender.health.damage_received.connect(_on_damage_received)
	_configured = true


func _physics_process(delta: float) -> void:
	if not _configured:
		return
	if not _game_flow.is_world_simulation_active():
		return
	if not _defender.health.is_alive():
		return

	_melee.tick(delta)
	if _melee.is_attacking():
		_defender.movement.pause()
		return
	if _update_retaliation_combat():
		return

	var assignment: CrewAssignmentRuntime = _roles.get_assignment(
		_defender.defender_id
	)
	if assignment == null:
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
		_try_start_attack(target)
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
	var retaliation: BoardingEnemy = _get_retaliation_target()
	if retaliation != null:
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
	_locked_enemy = null
	_retaliation_target = null
	_double_attack_follow_up_active = false
	if _melee != null:
		_melee.cancel()


func get_completed_hit_count() -> int:
	return _completed_hits


func get_retaliation_target_for_tests() -> BoardingEnemy:
	return _get_retaliation_target()


func debug_set_retaliation_target_for_tests(target: BoardingEnemy) -> void:
	_retaliation_target = target


static func is_local_x_on_forward_path(
	current_x: float,
	destination_x: float,
	candidate_x: float,
	epsilon: float = 0.01
) -> bool:
	var travel: float = destination_x - current_x
	if absf(travel) <= epsilon:
		return false
	var offset: float = candidate_x - current_x
	if absf(offset) <= epsilon:
		return true
	if signf(offset) != signf(travel):
		return false
	return absf(offset) <= absf(travel) + epsilon


func _update_retaliation_combat() -> bool:
	var target: BoardingEnemy = _get_retaliation_target()
	if target == null:
		return false
	var distance: float = absf(
		target.global_position.x - _defender.global_position.x
	)
	if distance <= _balance.defender_attack_range:
		_defender.movement.pause()
		_try_start_attack(target)
		return true
	var target_local_x: float = (
		target.global_position.x - _platform.global_position.x
	)
	_defender.movement.move_to(target_local_x)
	return true


func _get_retaliation_target() -> BoardingEnemy:
	if _retaliation_target == null:
		return null
	if not is_instance_valid(_retaliation_target):
		_retaliation_target = null
		return null
	if not _retaliation_target.health.is_alive():
		_retaliation_target = null
		return null
	return _retaliation_target


func _update_moving_assignment_combat() -> void:
	var target: BoardingEnemy = _get_moving_assignment_target()
	if target == null:
		_defender.movement.resume()
		return

	_defender.movement.pause()
	_try_start_attack(target)


func _get_moving_assignment_target() -> BoardingEnemy:
	var immediate: BoardingEnemy = _enemies.get_nearest_boarded_enemy(
		_defender.global_position,
		_balance.defender_attack_range
	)
	if immediate != null:
		return immediate

	var current_local_x: float = _defender.position.x
	var destination_local_x: float = _defender.movement.get_target_x()
	var selected: BoardingEnemy = null
	var selected_distance: float = INF
	for enemy: BoardingEnemy in _enemies.get_boarded_enemies():
		if enemy == null or not enemy.health.is_alive():
			continue
		var enemy_local_x: float = (
			enemy.global_position.x - _platform.global_position.x
		)
		if not is_local_x_on_forward_path(
			current_local_x,
			destination_local_x,
			enemy_local_x
		):
			continue
		var distance: float = absf(enemy_local_x - current_local_x)
		if distance > _balance.defender_attack_range:
			continue
		if distance > selected_distance:
			continue
		if (
			is_equal_approx(distance, selected_distance)
			and selected != null
			and enemy.enemy_id > selected.enemy_id
		):
			continue
		selected = enemy
		selected_distance = distance
	return selected


func _try_start_attack(target: BoardingEnemy) -> bool:
	if target == null or not target.health.is_alive():
		return false
	if not _melee.try_start(target.health):
		return false
	_locked_enemy = target
	_double_attack_follow_up_active = false
	return true


func _on_attack_landed(
	_target_health: HealthComponent,
	damage: int
) -> void:
	var primary: BoardingEnemy = _locked_enemy
	if primary == null or not is_instance_valid(primary):
		return
	var was_follow_up: bool = _double_attack_follow_up_active
	if was_follow_up:
		_double_attack_follow_up_active = false
	_completed_hits += 1
	var upgrades: MeleeDefenderUpgradeRuntime = (
		_defender.get_melee_upgrades()
	)
	if upgrades == null:
		return
	_resolver.resolve_primary_hit(
		_defender,
		primary,
		_enemies,
		upgrades,
		_completed_hits,
		damage,
		_balance.defender_attack_range
	)
	if (
		upgrades.duelist_double_attack
		and not was_follow_up
		and primary.health.is_alive()
		and _melee.queue_follow_up_same_target()
	):
		_double_attack_follow_up_active = true


func _on_damage_received(
	_requested_amount: int,
	_health_damage: int,
	source_id: StringName,
	source_node: Node
) -> void:
	if source_id != &"melee" or not _defender.health.is_alive():
		return
	var attacker: BoardingEnemy = source_node as BoardingEnemy
	if attacker == null:
		return
	_retaliation_target = attacker
	var upgrades: MeleeDefenderUpgradeRuntime = (
		_defender.get_melee_upgrades()
	)
	if upgrades == null:
		return
	_resolver.resolve_counterattack(
		_defender,
		attacker,
		upgrades,
		_balance.defender_attack_range,
		_melee.get_damage()
	)


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
		or (
			role_id == CrewRole.Id.MEDIC
			and _defender.can_medic_role_use_melee()
		)
	)
