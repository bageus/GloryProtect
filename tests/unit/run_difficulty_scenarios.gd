extends SceneTree


func _init() -> void:
	var difficulty_balance := RunDifficultyBalance.new()
	difficulty_balance.seconds_to_max_difficulty = 600.0
	difficulty_balance.growth_exponent = 1.0

	assert(is_equal_approx(
		difficulty_balance.get_normalized_for_elapsed(0.0),
		0.0
	))
	assert(is_equal_approx(
		difficulty_balance.get_normalized_for_elapsed(300.0),
		0.5
	))
	assert(is_equal_approx(
		difficulty_balance.get_normalized_for_elapsed(600.0),
		1.0
	))
	assert(is_equal_approx(
		difficulty_balance.get_normalized_for_elapsed(1200.0),
		1.0
	))
	assert(is_equal_approx(
		difficulty_balance.get_normalized_for_elapsed(-10.0),
		0.0
	))

	var boarding_balance := BoardingBalance.new()
	boarding_balance.spawn_interval = 3.0
	boarding_balance.minimum_spawn_interval = 0.8
	boarding_balance.max_ground_enemies = 8
	boarding_balance.maximum_ground_enemies = 20

	assert(is_equal_approx(
		boarding_balance.get_spawn_interval_for_difficulty(0.0),
		3.0
	))
	assert(is_equal_approx(
		boarding_balance.get_spawn_interval_for_difficulty(0.5),
		1.9
	))
	assert(is_equal_approx(
		boarding_balance.get_spawn_interval_for_difficulty(1.0),
		0.8
	))
	assert(boarding_balance.get_ground_limit_for_difficulty(0.0) == 8)
	assert(boarding_balance.get_ground_limit_for_difficulty(0.5) == 14)
	assert(boarding_balance.get_ground_limit_for_difficulty(1.0) == 20)

	print("Run difficulty scenarios passed")
	quit()
