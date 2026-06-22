class_name ShooterCombatController
extends Node

@export var base_profile: RangedAttackProfile = preload(
	"res://resources/crew/shooter_attack_profile.tres"
)
@export var target_policy: ShooterTargetPolicy = preload(
	"res://resources/crew/shooter_target_policy_default.tres"
)

var _configured: bool = false
var _defender: Defender
var _game_flow: GameFlowController
var _roles: CrewRoleManager
var _enemies: BoardingEnemyRegistry
var _crew: CrewManager
var _ranged: RangedAttackComponent
var _selector := ShooterTargetSelector.new()
var _locked_enemy: BoardingEnemy


func configure(
	defender: Defender,
	game_flow: GameFlowController,
	roles: CrewRoleManager,
	enemies: BoardingEnemyRegistry,
	crew: CrewManager,
	ranged: RangedAttackComponent
) -> void:
	assert(defender != null)
	assert(game_flow != null)
	assert(roles != null)
	assert(enemies != null)
	assert(crew != null)
	assert(ranged != null)
	assert(base_profile != null and base_profile.is_valid())
	assert(target_policy != null)
	_defender = defender
	_game_flow = game_flow
	_roles = roles
	_enemies = enemies
	_crew = crew
	_ranged = ranged
	_ranged.attack_finished.connect(_on_attack_finished)
	_configured = true


func _physics_process(_delta: float) -> void:
	if not _configured or not _game_flow.is_world_simulation_active():
		return
	if not _defender.health.is_alive():
		return
	var assignment: CrewAssignmentRuntime = _roles.get_assignment(
		_defender.defender_id
	)
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

	var upgrades: ShooterUpgradeRuntime = _crew.get_shooter_upgrades()
	var search_range: float = upgrades.get_range(base_profile.maximum_range)
	var target: BoardingEnemy = _selector.select_target(
		_enemies,
		_defender.global_position,
		search_range,
		target_policy
	)
	if target == null:
		return
	var profile: RangedAttackProfile = base_profile.duplicate(true) as RangedAttackProfile
	profile.damage = upgrades.get_damage(
		base_profile.damage,
		_get_target_domain(target)
	)
	profile.maximum_range = search_range
	profile.cooldown_duration = upgrades.get_cooldown(
		base_profile.cooldown_duration
	)
	_ranged.configure(profile, _defender, _game_flow)
	if _ranged.try_start(target.health):
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
	if _ranged != null:
		_ranged.cancel()


func get_locked_enemy() -> BoardingEnemy:
	return _locked_enemy


func _get_target_domain(enemy: BoardingEnemy) -> int:
	if enemy.behavior != null:
		return enemy.behavior.target_domain
	return EnemyBehaviorComponent.TargetDomain.GROUND


func _on_attack_finished() -> void:
	_locked_enemy = null
