extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var balance := PlatformBalance.new()
	balance.cell_count = 18
	balance.cell_width = 40.0
	balance.world_min_x = -2400.0
	balance.world_max_x = 2400.0
	var visual := GroundOrbVisualController.new()
	visual.platform_balance = balance
	visual.ground_spawn_route_margin = 760.0
	var platform_width: float = float(balance.cell_count) * balance.cell_width
	var ground_min_x: float = visual.get_ground_draw_min_x(platform_width)
	var ground_max_x: float = visual.get_ground_draw_max_x(platform_width)
	var half_width: float = platform_width * 0.5
	var left_spawn_x: float = balance.world_min_x - half_width - 720.0
	var right_spawn_x: float = balance.world_max_x + half_width + 720.0
	assert(ground_min_x <= left_spawn_x)
	assert(ground_max_x >= right_spawn_x)
	assert(is_equal_approx(ground_min_x, -3520.0))
	assert(is_equal_approx(ground_max_x, 3520.0))
	assert(is_equal_approx(
		absf(ground_min_x),
		absf(ground_max_x)
	))
	print("Ground visual extent scenarios passed")
	quit()
