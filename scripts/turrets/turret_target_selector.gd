class_name TurretTargetSelector
extends RefCounted


func get_nearest_target(
	registry: BoardingEnemyRegistry,
	world_origin: Vector2,
	maximum_range: float
) -> BoardingEnemy:
	var nearest: BoardingEnemy = null
	var nearest_distance_squared: float = maximum_range * maximum_range
	for enemy: BoardingEnemy in registry.get_all_enemies():
		if not is_still_targetable(enemy):
			continue
		if registry.get_unreserved_health(enemy.enemy_id) <= 0:
			continue
		var distance_squared: float = world_origin.distance_squared_to(
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


func is_still_targetable(enemy: BoardingEnemy) -> bool:
	return (
		enemy != null
		and is_instance_valid(enemy)
		and enemy.is_targetable_by_turret()
	)
