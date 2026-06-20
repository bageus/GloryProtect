extends SceneTree


func _init() -> void:
	var balance := StrategicWaveBalance.new()
	balance.initial_wave_interval = 12.0
	balance.minimum_wave_interval = 4.0
	balance.initial_wave_size = 6
	balance.maximum_wave_size = 30
	balance.initial_travel_duration = 8.0
	balance.minimum_travel_duration = 4.0
	balance.initial_target_sections = 1
	balance.maximum_target_sections = 3

	assert(is_equal_approx(balance.get_wave_interval(0.0), 12.0))
	assert(is_equal_approx(balance.get_wave_interval(0.5), 8.0))
	assert(is_equal_approx(balance.get_wave_interval(1.0), 4.0))
	assert(balance.get_wave_size(0.0) == 6)
	assert(balance.get_wave_size(0.5) == 18)
	assert(balance.get_wave_size(1.0) == 30)
	assert(is_equal_approx(balance.get_travel_duration(0.0), 8.0))
	assert(is_equal_approx(balance.get_travel_duration(0.5), 6.0))
	assert(is_equal_approx(balance.get_travel_duration(1.0), 4.0))
	assert(balance.get_target_section_count(0.0, 5) == 1)
	assert(balance.get_target_section_count(0.5, 5) == 2)
	assert(balance.get_target_section_count(1.0, 5) == 3)
	assert(balance.get_target_section_count(1.0, 2) == 2)
	assert(balance.get_target_section_count(1.0, 0) == 0)

	print("Strategic wave balance scenarios passed")
	quit()
