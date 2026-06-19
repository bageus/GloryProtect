extends SceneTree


func _init() -> void:
	_test_platform_geometry_comes_from_resource()
	_test_wind_levels_come_from_resource()
	_test_missing_driver_blocks_steering()
	print("Platform resource scenarios passed")
	quit()


func _test_platform_geometry_comes_from_resource() -> void:
	var balance := PlatformBalance.new()
	balance.cell_count = 20
	balance.cell_width = 32.0
	balance.platform_height = 64.0

	var platform := PlatformController.new()
	platform.balance = balance

	assert(is_equal_approx(platform.get_platform_width(), 640.0))
	assert(is_equal_approx(platform.get_platform_height(), 64.0))


func _test_wind_levels_come_from_resource() -> void:
	var balance := WindBalance.new()
	balance.level_forces = PackedFloat32Array([10.0, 20.0, 30.0])
	balance.fluctuation_force = 0.0

	var wind := WindSystem.new()
	wind.balance = balance
	wind.set_debug_state(-1, 3)

	assert(is_equal_approx(wind.get_base_force(), 30.0))
	assert(is_equal_approx(wind.get_current_force(), -30.0))


func _test_missing_driver_blocks_steering() -> void:
	var steering := SteeringInputProvider.new()
	steering.set_driver_available(false)
	assert(is_zero_approx(steering.get_steering_axis()))
	assert(not steering.is_control_input_active())
