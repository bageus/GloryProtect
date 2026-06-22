class_name ShooterCombatController
extends Node

@export var base_profile: RangedAttackProfile = preload("res://resources/crew/shooter_attack_profile.tres")
@export var target_policy: ShooterTargetPolicy = preload("res://resources/crew/shooter_target_policy_default.tres")
@export var specialization_balance: ShooterSpecializationBalance = preload("res://resources/balance/shooter_specialization_balance.tres")

var _configured := false
var _defender: Defender
var _game_flow: GameFlowController
var _roles: CrewRoleManager
var _enemies: BoardingEnemyRegistry
var _crew: CrewManager
var _ranged: RangedAttackComponent
var _selector := ShooterTargetSelector.new()
var _resolver := ShooterCombatResolver.new()
var _locked_enemy: BoardingEnemy
var _active_policy: ShooterTargetPolicy
var _completed_bolts := 0
var _completed_volleys := 0


func configure(
	defender: Defender,
	game_flow: GameFlowController,
	roles: CrewRoleManager,
	enemies: BoardingEnemyRegistry,
	crew: CrewManager,
	ranged: RangedAttackComponent
) -> void:
	assert(defender != null and game_flow != null and roles != null)
	assert(enemies != null and crew != null and ranged != null)
	assert(base_profile != null and base_profile.is_valid())
	assert(target_policy != null)
	assert(specialization_balance != null and specialization_balance.is_valid())
	_defender = defender
	_game_flow = game_flow
	_roles = roles
	_enemies = enemies
	_crew = crew
	_ranged = ranged
	_ranged.configure(
		base_profile.duplicate(true) as RangedAttackProfile,
		_defender,
		_game_flow
	)
	_resolver.configure(specialization_balance)
	if not _ranged.attack_landed.is_connected(_on_attack_landed):
		_ranged.attack_landed.connect(_on_attack_landed)
	if not _ranged.attack_finished.is_connected(_on_attack_finished):
		_ranged.attack_finished.connect(_on_attack_finished)
	_configured = true


func _physics_process(_delta: float) -> void:
	if not _configured or not _game_flow.is_world_simulation_active():
		return
	if not _defender.health.is_alive():
		return
	var assignment := _roles.get_assignment(_defender.defender_id)
	if assignment == null:
		return
	if assignment.current_role != CrewRole.Id.SHOOTER:
		return
	if assignment.state != CrewAssignmentRuntime.State.ACTIVE:
		return
	if not _crew.is_shooter_role_unlocked():
		return
	if is_action_active():
		_defender.movement.pause()
		return
	if not _ranged.can_start():
		return
	var upgrades := _crew.get_shooter_upgrades()
	_active_policy = _build_policy(upgrades)
	var search_range := upgrades.get_range(base_profile.maximum_range)
	var target := _selector.select_target(
		_enemies,
		_defender.global_position,
		search_range,
		_active_policy
	)
	if target == null:
		return
	var profile := base_profile.duplicate(true) as RangedAttackProfile
	profile.damage = upgrades.get_damage(
		base_profile.damage,
		target.get_target_domain(),
		target.is_counted_as_climbing()
	)
	profile.maximum_range = search_range
	profile.cooldown_duration = upgrades.get_cooldown(
		base_profile.cooldown_duration
	)
	profile.cooldown_duration /= (
		_defender.get_temporary_attack_speed_multiplier()
	)
	_ranged.configure(profile, _defender, _game_flow)
	var shot_count: int = 1
	if upgrades.air_triple_shot or upgrades.anchor_triple_shot:
		shot_count = 3
	if _ranged.try_start_sequence(target.health, shot_count):
		_locked_enemy = target
		_defender.movement.pause()


func is_action_active() -> bool:
	if not _configured or _ranged == null:
		return false
	return _ranged.phase in [
		RangedAttackComponent.Phase.WINDUP,
		RangedAttackComponent.Phase.PROJECTILE,
	]


func cancel() -> void:
	_locked_enemy = null
	_active_policy = null
	if _ranged != null:
		_ranged.cancel()


func reset_for_run() -> void:
	cancel()
	_completed_bolts = 0
	_completed_volleys = 0


func get_locked_enemy() -> BoardingEnemy:
	return _locked_enemy


func get_completed_bolt_count() -> int:
	return _completed_bolts


func get_completed_volley_count() -> int:
	return _completed_volleys


func _build_policy(
	upgrades: ShooterUpgradeRuntime
) -> ShooterTargetPolicy:
	var policy := target_policy.duplicate(true) as ShooterTargetPolicy
	match upgrades.specialization_id:
		ShooterUpgradeRuntime.SNIPER:
			policy.priority_mode = ShooterTargetPolicy.PriorityMode.STRONGEST
		ShooterUpgradeRuntime.AIR_HUNTER:
			policy.priority_mode = ShooterTargetPolicy.PriorityMode.AIR_FIRST
		ShooterUpgradeRuntime.ANCHOR_HUNTER:
			policy.priority_mode = ShooterTargetPolicy.PriorityMode.ANCHOR_FIRST
	return policy


func _on_attack_landed(
	_target_health: HealthComponent,
	damage: int
) -> void:
	if _locked_enemy == null or not is_instance_valid(_locked_enemy):
		return
	_completed_bolts += 1
	_resolver.resolve_bolt_hit(
		_defender,
		_locked_enemy,
		_enemies,
		_active_policy,
		_crew.get_shooter_upgrades(),
		damage,
		_completed_bolts
	)


func _on_attack_finished() -> void:
	_completed_volleys += 1
	_resolver.resolve_volley_finished(
		_locked_enemy,
		_crew.get_shooter_upgrades(),
		_completed_volleys
	)
	_locked_enemy = null
	_active_policy = null
