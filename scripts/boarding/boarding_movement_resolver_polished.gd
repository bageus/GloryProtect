class_name BoardingMovementResolverPolished
extends BoardingMovementResolver


func can_exit_to_platform(enemy: BoardingEnemy, local_x: float) -> bool:
	var platform_half_width: float = _platform.get_platform_width() * 0.5
	var enemy_radius: float = enemy.get_body_radius()
	if local_x < -platform_half_width + enemy_radius:
		return false
	if local_x > platform_half_width - enemy_radius:
		return false

	for other: BoardingEnemy in _enemies.get_boarded_enemies():
		if other == enemy:
			continue
		if (
			absf(other.controller.get_platform_occupancy_x() - local_x)
			< get_enemy_gap(
				enemy,
				other,
				boarding_balance.platform_enemy_spacing
			)
		):
			return false
	return true
