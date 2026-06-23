class_name ShooterCombatResolver
extends RefCounted

var _balance: ShooterSpecializationBalance


func configure(balance: ShooterSpecializationBalance) -> void:
	assert(balance != null and balance.is_valid())
	_balance = balance


func resolve_bolt_hit(
	shooter: Defender,
	primary: BoardingEnemy,
	enemies: BoardingEnemyRegistry,
	policy: ShooterTargetPolicy,
	upgrades: ShooterUpgradeRuntime,
	damage: int,
	completed_bolts: int,
	maximum_range: float
) -> void:
	if shooter == null or primary == null or not is_instance_valid(primary):
		return
	if policy == null or maximum_range <= 0.0:
		return
	if upgrades.piercing_enabled or upgrades.sniper_multi_pierce:
		var target_count: int = _balance.base_pierce_target_count
		if upgrades.sniper_multi_pierce:
			target_count = _balance.sniper_pierce_target_count
		_apply_piercing(
			shooter,
			primary,
			enemies,
			policy,
			damage,
			target_count,
			maximum_range
		)
	if upgrades.sniper_explosive_fifth and completed_bolts % 5 == 0:
		_apply_explosion(
			primary.global_position,
			primary,
			enemies,
			policy,
			damage
		)
	if upgrades.air_mark_fifth and completed_bolts % 5 == 0:
		_mark_strongest_air_target(enemies)


func resolve_volley_finished(
	primary: BoardingEnemy,
	upgrades: ShooterUpgradeRuntime,
	completed_volleys: int
) -> bool:
	if not upgrades.anchor_knockdown_fifth:
		return false
	if completed_volleys % 5 != 0:
		return false
	if primary == null or not is_instance_valid(primary):
		return false
	return primary.knock_down_from_anchor()


func _apply_piercing(
	shooter: Defender,
	primary: BoardingEnemy,
	enemies: BoardingEnemyRegistry,
	policy: ShooterTargetPolicy,
	damage: int,
	maximum_targets: int,
	maximum_range: float
) -> void:
	var shot_vector: Vector2 = (
		primary.global_position - shooter.global_position
	)
	if shot_vector.is_zero_approx():
		return
	var direction: Vector2 = shot_vector.normalized()
	var primary_forward: float = shot_vector.length()
	var candidates: Array[BoardingEnemy] = []
	for enemy: BoardingEnemy in enemies.get_all_enemies():
		if enemy == primary or not policy.is_valid_target(enemy):
			continue
		var relative: Vector2 = (
			enemy.global_position - shooter.global_position
		)
		var forward: float = relative.dot(direction)
		if forward <= primary_forward or forward > maximum_range:
			continue
		var perpendicular: float = absf(direction.cross(relative))
		if perpendicular > _balance.piercing_lane_half_height:
			continue
		candidates.append(enemy)
	candidates.sort_custom(func(first: BoardingEnemy, second: BoardingEnemy) -> bool:
		return shooter.global_position.distance_squared_to(first.global_position) < shooter.global_position.distance_squared_to(second.global_position)
	)
	for index: int in range(mini(maximum_targets, candidates.size())):
		candidates[index].health.apply_damage(
			damage,
			&"shooter_pierce",
			shooter
		)


func _apply_explosion(
	center: Vector2,
	primary: BoardingEnemy,
	enemies: BoardingEnemyRegistry,
	policy: ShooterTargetPolicy,
	damage: int
) -> void:
	var radius_squared: float = (
		_balance.explosive_radius * _balance.explosive_radius
	)
	for enemy: BoardingEnemy in enemies.get_all_enemies():
		if enemy == primary or not policy.is_valid_target(enemy):
			continue
		if center.distance_squared_to(enemy.global_position) > radius_squared:
			continue
		enemy.health.apply_damage(damage, &"shooter_explosion")


func _mark_strongest_air_target(
	enemies: BoardingEnemyRegistry
) -> void:
	var strongest: BoardingEnemy = null
	var strongest_health: int = -1
	for enemy: BoardingEnemy in enemies.get_all_enemies():
		if not enemy.health.is_alive():
			continue
		if enemy.get_target_domain() != EnemyBehaviorComponent.TargetDomain.AIR:
			continue
		if enemy.health.current_health <= strongest_health:
			continue
		strongest = enemy
		strongest_health = enemy.health.current_health
	if strongest != null:
		strongest.apply_damage_mark(
			_balance.mark_duration,
			_balance.mark_damage_multiplier
		)
