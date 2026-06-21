class_name MeleeDefenderCombatResolver
extends RefCounted

const SPLASH_DAMAGE: int = 1
const HEAVY_BASH_KNOCKBACK: float = 40.0


func resolve_primary_hit(
	defender: Defender,
	primary: BoardingEnemy,
	registry: BoardingEnemyRegistry,
	upgrades: MeleeDefenderUpgradeRuntime,
	completed_hits: int,
	base_damage: int,
	attack_range: float
) -> void:
	if defender == null or primary == null or not is_instance_valid(primary):
		return
	if (
		upgrades.duelist_isolated_damage
		and primary.health.is_alive()
		and _is_isolated_target(primary, registry, attack_range)
	):
		primary.health.apply_damage(1, &"melee_extra")
	if upgrades.duelist_double_attack and primary.health.is_alive():
		primary.health.apply_damage(base_damage, &"melee_extra")
	if upgrades.assault_splash:
		_apply_targets_behind_primary(
			defender,
			primary,
			registry,
			3,
			SPLASH_DAMAGE,
			false
		)
	if upgrades.assault_back_attack:
		if primary.health.is_alive():
			primary.health.apply_damage(base_damage, &"melee_extra")
		var rear: BoardingEnemy = _get_nearest_enemy_on_opposite_side(
			defender,
			primary,
			registry,
			attack_range
		)
		if rear != null:
			rear.health.apply_damage(base_damage, &"melee_extra")
	if upgrades.heavy_shield_bash and completed_hits % 5 == 0:
		_apply_targets_behind_primary(
			defender,
			primary,
			registry,
			2,
			SPLASH_DAMAGE,
			true
		)


func resolve_counterattack(
	defender: Defender,
	registry: BoardingEnemyRegistry,
	upgrades: MeleeDefenderUpgradeRuntime,
	attack_range: float,
	damage: int
) -> bool:
	if not upgrades.duelist_counterattack:
		return false
	var target: BoardingEnemy = registry.get_nearest_boarded_enemy(
		defender.global_position,
		attack_range
	)
	if target == null:
		return false
	target.health.apply_damage(damage, &"counterattack")
	return true


func _is_isolated_target(
	primary: BoardingEnemy,
	registry: BoardingEnemyRegistry,
	attack_range: float
) -> bool:
	var radius_squared: float = attack_range * attack_range * 4.0
	for enemy: BoardingEnemy in registry.get_boarded_enemies():
		if enemy == primary:
			continue
		if primary.global_position.distance_squared_to(enemy.global_position) <= radius_squared:
			return false
	return true


func _apply_targets_behind_primary(
	defender: Defender,
	primary: BoardingEnemy,
	registry: BoardingEnemyRegistry,
	maximum_targets: int,
	damage: int,
	knockback: bool
) -> void:
	var direction: float = signf(
		primary.global_position.x - defender.global_position.x
	)
	if is_zero_approx(direction):
		direction = 1.0
	var candidates: Array[BoardingEnemy] = []
	for enemy: BoardingEnemy in registry.get_boarded_enemies():
		if enemy == primary:
			continue
		if (enemy.global_position.x - primary.global_position.x) * direction <= 0.0:
			continue
		candidates.append(enemy)
	candidates.sort_custom(func(first: BoardingEnemy, second: BoardingEnemy) -> bool:
		return primary.global_position.distance_squared_to(first.global_position) < primary.global_position.distance_squared_to(second.global_position)
	)
	for index: int in range(mini(maximum_targets, candidates.size())):
		var enemy: BoardingEnemy = candidates[index]
		enemy.health.apply_damage(damage, &"melee_splash")
		if knockback and enemy.health.is_alive():
			enemy.apply_platform_knockback(
				HEAVY_BASH_KNOCKBACK,
				defender.global_position.x
			)


func _get_nearest_enemy_on_opposite_side(
	defender: Defender,
	primary: BoardingEnemy,
	registry: BoardingEnemyRegistry,
	attack_range: float
) -> BoardingEnemy:
	var primary_direction: float = signf(
		primary.global_position.x - defender.global_position.x
	)
	if is_zero_approx(primary_direction):
		return null
	var nearest: BoardingEnemy = null
	var nearest_distance_squared: float = attack_range * attack_range
	for enemy: BoardingEnemy in registry.get_boarded_enemies():
		if enemy == primary:
			continue
		var enemy_direction: float = signf(
			enemy.global_position.x - defender.global_position.x
		)
		if enemy_direction == primary_direction or is_zero_approx(enemy_direction):
			continue
		var distance_squared: float = defender.global_position.distance_squared_to(
			enemy.global_position
		)
		if distance_squared >= nearest_distance_squared:
			continue
		nearest = enemy
		nearest_distance_squared = distance_squared
	return nearest
