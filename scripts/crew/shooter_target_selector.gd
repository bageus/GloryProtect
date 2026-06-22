class_name ShooterTargetSelector
extends RefCounted


func select_target(
	enemies: BoardingEnemyRegistry,
	origin: Vector2,
	maximum_range: float,
	policy: ShooterTargetPolicy
) -> BoardingEnemy:
	if enemies == null or policy == null or maximum_range <= 0.0:
		return null
	var selected: BoardingEnemy = null
	var selected_score: float = -INF
	var range_squared: float = maximum_range * maximum_range
	for enemy: BoardingEnemy in enemies.get_all_enemies():
		if not policy.is_valid_target(enemy):
			continue
		if origin.distance_squared_to(enemy.global_position) > range_squared:
			continue
		var score: float = policy.get_priority_score(enemy, origin)
		if score <= selected_score:
			continue
		selected = enemy
		selected_score = score
	return selected
