class_name TurretCombatResolver
extends RefCounted

var _balance: TurretUpgradeBalance
var _random := RandomNumberGenerator.new()


func configure(balance: TurretUpgradeBalance, seed: int = 0) -> void:
	assert(balance != null and balance.is_valid())
	_balance = balance
	if seed == 0:
		_random.randomize()
	else:
		_random.seed = seed


func resolve_shot(
	primary: BoardingEnemy,
	origin: Vector2,
	registry: BoardingEnemyRegistry,
	upgrades: TurretUpgradeRuntime,
	turret_runtime: TurretRuntime,
	base_damage: int
) -> int:
	if primary == null or not primary.is_targetable_by_turret():
		return 0
	var damage: int = upgrades.get_damage(base_damage)
	var hits: int = _apply_damage(primary, damage)
	if upgrades.double_shot_enabled:
		hits += _apply_damage(primary, damage)
	if upgrades.extra_fifth_shot_enabled and turret_runtime.is_fifth_volley():
		hits += _apply_damage(primary, damage)
	if upgrades.piercing_enabled:
		hits += _apply_piercing(primary, origin, registry, damage)
	if upgrades.explosive_fifth_enabled and turret_runtime.is_fifth_volley():
		hits += _apply_area_damage(
			primary.global_position,
			registry,
			_balance.explosive_radius,
			damage,
			primary.enemy_id
		)
	if upgrades.stun_enabled and primary.health.is_alive():
		primary.apply_stun(_random.randf_range(
			_balance.stun_min_seconds,
			_balance.stun_max_seconds
		))
	if upgrades.chain_enabled:
		hits += _apply_chain(primary, registry)
	if upgrades.electric_orb_enabled and turret_runtime.is_fifth_volley():
		hits += _apply_area_damage(
			primary.global_position,
			registry,
			_balance.electric_orb_radius,
			_balance.electric_orb_damage,
			-1
		)
	return hits


func _apply_piercing(
	primary: BoardingEnemy,
	origin: Vector2,
	registry: BoardingEnemyRegistry,
	damage: int
) -> int:
	var direction: float = signf(primary.global_position.x - origin.x)
	if is_zero_approx(direction):
		direction = 1.0
	var nearest: BoardingEnemy = null
	var nearest_forward: float = INF
	for enemy: BoardingEnemy in registry.get_turret_targets():
		if enemy.enemy_id == primary.enemy_id:
			continue
		var forward: float = (
			(enemy.global_position.x - primary.global_position.x) * direction
		)
		if forward <= 0.0 or forward >= nearest_forward:
			continue
		if absf(enemy.global_position.y - primary.global_position.y) > (
			_balance.piercing_lane_half_height
		):
			continue
		nearest = enemy
		nearest_forward = forward
	return _apply_damage(nearest, damage)


func _apply_chain(
	primary: BoardingEnemy,
	registry: BoardingEnemyRegistry
) -> int:
	var nearest: BoardingEnemy = null
	var nearest_distance_squared: float = _balance.chain_range * _balance.chain_range
	for enemy: BoardingEnemy in registry.get_turret_targets():
		if enemy.enemy_id == primary.enemy_id:
			continue
		var distance_squared: float = primary.global_position.distance_squared_to(
			enemy.global_position
		)
		if distance_squared >= nearest_distance_squared:
			continue
		nearest = enemy
		nearest_distance_squared = distance_squared
	return _apply_damage(nearest, _balance.chain_damage)


func _apply_area_damage(
	center: Vector2,
	registry: BoardingEnemyRegistry,
	radius: float,
	damage: int,
	excluded_enemy_id: int
) -> int:
	var hits: int = 0
	var radius_squared: float = radius * radius
	for enemy: BoardingEnemy in registry.get_turret_targets():
		if enemy.enemy_id == excluded_enemy_id:
			continue
		if center.distance_squared_to(enemy.global_position) > radius_squared:
			continue
		hits += _apply_damage(enemy, damage)
	return hits


func _apply_damage(enemy: BoardingEnemy, damage: int) -> int:
	if enemy == null or not is_instance_valid(enemy):
		return 0
	if not enemy.health.is_alive() or damage <= 0:
		return 0
	enemy.health.apply_damage(damage)
	return 1
