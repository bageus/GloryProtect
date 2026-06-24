class_name TurretCombatResolver
extends RefCounted

var _balance: TurretUpgradeBalance
var _random := RandomNumberGenerator.new()


func configure(balance: TurretUpgradeBalance, random_seed: int = 0) -> void:
	assert(balance != null and balance.is_valid())
	_balance = balance
	if random_seed == 0:
		_random.randomize()
	else:
		_random.seed = random_seed


func resolve_shot(
	primary: BoardingEnemy,
	origin: Vector2,
	maximum_range: float,
	registry: BoardingEnemyRegistry,
	upgrades: TurretUpgradeRuntime,
	base_damage: int,
	is_fifth_shot: bool = false,
	is_fifth_volley: bool = false
) -> int:
	if not _is_damageable(primary):
		return 0
	var normal_damage: int = upgrades.get_damage(base_damage)
	var electric_orb: bool = (
		upgrades.electric_orb_fifth_enabled
		and is_fifth_volley
	)
	var hits: int = 0
	if electric_orb:
		hits += _apply_area_damage(
			primary.global_position,
			_balance.electric_orb_radius,
			_balance.electric_orb_damage,
			registry,
			true
		)
	else:
		hits += _apply_damage(primary, normal_damage)
		if upgrades.piercing_enabled:
			hits += _apply_line_piercing(
				primary,
				origin,
				maximum_range,
				registry,
				normal_damage
			)
		if upgrades.stun_enabled:
			_apply_stun(primary)
		if upgrades.heavy_explosive_fifth_enabled and is_fifth_shot:
			hits += _apply_area_damage(
				primary.global_position,
				_balance.heavy_explosion_radius,
				_balance.heavy_explosion_damage,
				registry,
				false
			)
	if upgrades.chain_enabled:
		var secondary: BoardingEnemy = _choose_chain_target(
			primary,
			origin,
			maximum_range,
			registry
		)
		hits += _apply_damage(secondary, normal_damage)
		if upgrades.stun_enabled:
			_apply_stun(secondary)
	return hits


func _apply_line_piercing(
	primary: BoardingEnemy,
	origin: Vector2,
	maximum_range: float,
	registry: BoardingEnemyRegistry,
	damage: int
) -> int:
	var shot_vector: Vector2 = primary.global_position - origin
	if shot_vector.is_zero_approx():
		return 0
	var direction: Vector2 = shot_vector.normalized()
	var primary_forward: float = shot_vector.length()
	var hits: int = 0
	for enemy: BoardingEnemy in registry.get_turret_targets():
		if enemy.enemy_id == primary.enemy_id or not _is_damageable(enemy):
			continue
		var relative: Vector2 = enemy.global_position - origin
		var forward: float = relative.dot(direction)
		if forward <= primary_forward or forward > maximum_range:
			continue
		var perpendicular: float = absf(direction.cross(relative))
		if perpendicular > enemy.get_body_radius():
			continue
		hits += _apply_damage(enemy, damage)
	return hits


func _apply_area_damage(
	center: Vector2,
	radius: float,
	damage: int,
	registry: BoardingEnemyRegistry,
	stun_targets: bool
) -> int:
	var hits: int = 0
	var radius_squared: float = radius * radius
	for enemy: BoardingEnemy in registry.get_turret_targets():
		if not _is_damageable(enemy):
			continue
		if center.distance_squared_to(enemy.global_position) > radius_squared:
			continue
		hits += _apply_damage(enemy, damage)
		if stun_targets:
			_apply_stun(enemy)
	return hits


func _choose_chain_target(
	primary: BoardingEnemy,
	origin: Vector2,
	maximum_range: float,
	registry: BoardingEnemyRegistry
) -> BoardingEnemy:
	var nearest: BoardingEnemy = null
	var nearest_distance_squared: float = INF
	var range_squared: float = maximum_range * maximum_range
	for enemy: BoardingEnemy in registry.get_turret_targets():
		if enemy.enemy_id == primary.enemy_id or not _is_damageable(enemy):
			continue
		if origin.distance_squared_to(enemy.global_position) > range_squared:
			continue
		var distance_squared: float = primary.global_position.distance_squared_to(
			enemy.global_position
		)
		if distance_squared > nearest_distance_squared:
			continue
		if (
			is_equal_approx(distance_squared, nearest_distance_squared)
			and nearest != null
			and enemy.enemy_id > nearest.enemy_id
		):
			continue
		nearest = enemy
		nearest_distance_squared = distance_squared
	return nearest


func _apply_damage(enemy: BoardingEnemy, damage: int) -> int:
	if not _is_damageable(enemy) or damage <= 0:
		return 0
	enemy.health.apply_damage(damage)
	return 1


func _apply_stun(enemy: BoardingEnemy) -> void:
	if not _is_damageable(enemy):
		return
	enemy.apply_stun(_random.randf_range(
		_balance.stun_min_seconds,
		_balance.stun_max_seconds
	))


func _is_damageable(enemy: BoardingEnemy) -> bool:
	return (
		enemy != null
		and is_instance_valid(enemy)
		and enemy.health.is_alive()
		and enemy.is_targetable_by_turret()
	)
