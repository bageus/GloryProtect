extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_run_difficulty_curve()
	_test_boarding_pressure_curve()
	_test_strategic_pressure_curve()
	_test_flying_pressure_curve()
	print("NEXT-18 balance curve scenarios passed")
	quit()


func _test_run_difficulty_curve() -> void:
	var balance := RunDifficultyBalance.new()
	balance.seconds_to_max_difficulty = 720.0
	balance.overtime_step_seconds = 120.0
	balance.maximum_overtime_tier = 6
	assert(is_equal_approx(balance.get_normalized_for_elapsed(0.0), 0.0))
	assert(is_equal_approx(balance.get_normalized_for_elapsed(360.0), 0.5))
	assert(is_equal_approx(balance.get_normalized_for_elapsed(720.0), 1.0))
	assert(balance.get_overtime_tier_for_elapsed(719.0) == 0)
	assert(balance.get_overtime_tier_for_elapsed(720.0) == 1)
	assert(balance.get_overtime_tier_for_elapsed(840.0) == 2)
	assert(balance.get_overtime_tier_for_elapsed(10000.0) == 6)


func _test_boarding_pressure_curve() -> void:
	var balance := BoardingBalance.new()
	balance.spawn_interval = 1.0
	balance.minimum_spawn_interval = 0.27
	balance.max_ground_enemies = 24
	balance.maximum_ground_enemies = 84
	balance.overtime_ground_limit_per_tier = 6
	balance.maximum_overtime_ground_enemies = 108
	balance.overtime_spawn_interval_multiplier = 0.95
	balance.minimum_overtime_spawn_interval = 0.2
	assert(is_equal_approx(balance.get_spawn_interval_for_difficulty(0.0), 1.0))
	assert(is_equal_approx(balance.get_spawn_interval_for_difficulty(1.0), 0.27))
	assert(is_equal_approx(balance.get_spawn_interval_for_difficulty(1.0, 1), 0.2565))
	assert(is_equal_approx(balance.get_spawn_interval_for_difficulty(1.0, 6), 0.2))
	assert(balance.get_ground_limit_for_difficulty(0.0) == 24)
	assert(balance.get_ground_limit_for_difficulty(1.0) == 84)
	assert(balance.get_ground_limit_for_difficulty(1.0, 1) == 90)
	assert(balance.get_ground_limit_for_difficulty(1.0, 6) == 108)


func _test_strategic_pressure_curve() -> void:
	var balance := StrategicWaveBalance.new()
	balance.initial_wave_interval = 12.0
	balance.minimum_wave_interval = 5.5
	balance.initial_wave_size = 6
	balance.maximum_wave_size = 30
	balance.overtime_wave_size_per_tier = 3
	balance.maximum_overtime_wave_size = 48
	assert(is_equal_approx(balance.get_wave_interval(0.0), 12.0))
	assert(is_equal_approx(balance.get_wave_interval(1.0), 5.5))
	assert(balance.get_wave_size(0.0) == 6)
	assert(balance.get_wave_size(1.0) == 30)
	assert(balance.get_wave_size(1.0, 1) == 33)
	assert(balance.get_wave_size(1.0, 6) == 48)


func _test_flying_pressure_curve() -> void:
	var profile := FlyingEnemyProfile.new()
	profile.spawn_interval = 6.0
	profile.minimum_spawn_interval = 2.7
	profile.overtime_spawn_interval_multiplier = 0.95
	profile.minimum_overtime_spawn_interval = 2.0
	assert(is_equal_approx(profile.get_spawn_interval(0.0), 6.0))
	assert(is_equal_approx(profile.get_spawn_interval(1.0), 2.7))
	assert(is_equal_approx(profile.get_spawn_interval(1.0, 1), 2.565))
	assert(is_equal_approx(profile.get_spawn_interval(1.0, 6), 2.0))
