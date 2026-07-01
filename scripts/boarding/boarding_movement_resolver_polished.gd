class_name BoardingMovementResolverPolished
extends BoardingMovementResolver


func resolve_ground_x(
	enemy: BoardingEnemy,
	current_x: float,
	desired_x: float
) -> float:
	var resolved_x: float = desired_x
	var movement_direction: float = signf(desired_x - current_x)
	for other: BoardingEnemy in _enemies.get_all_enemies():
		if other == enemy or not other.health.is_alive():
			continue
		if not other.is_counted_as_ground():
			continue
		if _are_ground_enemies_moving_opposite(
			movement_direction,
			other
		):
			continue
		resolved_x = _clamp_step_against_obstacle(
			current_x,
			resolved_x,
			other.global_position.x,
			get_enemy_gap(
				enemy,
				other,
				boarding_balance.ground_enemy_spacing
			)
		)
	return resolved_x


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


func _are_ground_enemies_moving_opposite(
	movement_direction: float,
	other: BoardingEnemy
) -> bool:
	if is_zero_approx(movement_direction):
		return false
	var routed_other := other as SurfaceAlignedBoardingEnemy
	if routed_other == null:
		return false
	var other_direction: float = signf(
		routed_other.get_ground_target_x() - other.global_position.x
	)
	return (
		not is_zero_approx(other_direction)
		and movement_direction != other_direction
	)
