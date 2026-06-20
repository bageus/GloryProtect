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
		if not _is_valid_target(enemy):
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
	return _is_valid_target(enemy)


func _is_valid_target(enemy: BoardingEnemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if not enemy.health.is_alive():
		return false
	return (
		enemy.get_state() == BoardingEnemyController.State.CLIMBING
		or enemy.is_on_platform()
	)
