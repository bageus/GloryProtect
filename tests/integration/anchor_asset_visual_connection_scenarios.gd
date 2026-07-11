extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var platform := PlatformController.new()
	platform.balance = PlatformBalance.new()
	platform.balance.cell_count = 18
	platform.balance.cell_width = 40.0
	platform.balance.platform_height = 58.0
	platform.position = Vector2(100.0, 300.0)

	var anchor_balance := AnchorBalance.new()
	anchor_balance.platform_attachment_y_factor = 0.45
	var geometry := AnchorGeometry.new()
	geometry.configure(platform, anchor_balance, null)

	var combat_system := CombatAnchorSystem.new()
	var visual := AnchorVisualControllerPolished.new()
	visual.configure_combat(
		AnchorRuntimeStore.new(),
		geometry,
		anchor_balance,
		Callable(self, "_is_operator_available"),
		Callable(self, "_is_simulation_active"),
		null,
		combat_system
	)
	root.add_child(visual)

	assert(is_equal_approx(visual.get_winch_scale_multiplier_for_tests(), 0.55545))
	assert(is_equal_approx(visual.stowed_chain_length, 38.0))
	var expected_anchor_rect := Rect2(
		Vector2(157.0, 162.0),
		Vector2(198.0, 252.0)
	)
	var expected_clamp_rect := Rect2(
		Vector2(169.0, 188.0),
		Vector2(173.0, 174.0)
	)
	assert(visual.get_base_anchor_source_rect_for_tests() == expected_anchor_rect)
	assert(visual.get_base_clamp_source_rect_for_tests() == expected_clamp_rect)
	assert(
		visual.get_registered_base_anchor_source_rect_for_tests()
		== expected_anchor_rect
	)
	assert(
		visual.get_registered_base_clamp_source_rect_for_tests()
		== expected_clamp_rect
	)
	assert(
		visual.get_trap_winch_source_rect_for_tests()
		== Rect2(Vector2(36.0, 108.0), Vector2(463.0, 296.0))
	)

	var base_winch_size: Vector2 = visual.get_winch_visual_size_for_tests(0)
	assert(base_winch_size.is_equal_approx(Vector2(45.88017, 26.77269)))
	assert(base_winch_size.x > platform.balance.cell_width)
	var left_winch_bottom: Vector2 = visual.get_winch_visual_bottom(0)
	var right_winch_bottom: Vector2 = visual.get_winch_visual_bottom(3)
	assert(visual.get_winch_chain_exit(0).is_equal_approx(left_winch_bottom))
	assert(visual.get_winch_chain_exit(3).is_equal_approx(right_winch_bottom))

	var overlap_ratio: float = visual.get_chain_socket_overlap_ratio_for_tests()
	var overlap_depth: float = visual.get_chain_socket_overlap_depth_for_tests()
	assert(is_equal_approx(overlap_ratio, 1.0 / 3.0))
	assert(is_equal_approx(overlap_depth, visual.chain_tile_height / 3.0))
	var socket_start := Vector2(0.0, 0.0)
	var socket_finish := Vector2(0.0, 100.0)
	var socket_segment: PackedVector2Array = (
		visual.get_chain_socket_segment_for_tests(socket_start, socket_finish)
	)
	assert(socket_segment.size() == 2)
	var tile_half_height: float = visual.chain_tile_height * 0.5
	assert(is_equal_approx(
		socket_start.y - (socket_segment[0].y - tile_half_height),
		overlap_depth
	))
	assert(is_equal_approx(
		(socket_segment[1].y + tile_half_height) - socket_finish.y,
		overlap_depth
	))

	var platform_bottom_y: float = (
		platform.position.y + platform.balance.platform_height * 0.5
	)
	var stowed_anchor_top: Vector2 = visual.get_stowed_anchor_draw_top_for_tests(0)
	var stowed_anchor_rect: Rect2 = visual.get_stowed_anchor_rect_for_tests(0)
	var anchor_socket: Vector2 = visual.get_anchor_chain_socket_for_tests(
		stowed_anchor_top
	)
	assert(anchor_socket.is_equal_approx(Vector2(
		stowed_anchor_rect.position.x + stowed_anchor_rect.size.x * 0.5,
		stowed_anchor_rect.position.y
	)))
	assert(is_equal_approx(
		anchor_socket.y - left_winch_bottom.y,
		visual.chain_tile_height / 3.0
	))
	var anchor_protrusion := stowed_anchor_rect.end.y - platform_bottom_y
	assert(anchor_protrusion > 0.0)
	assert(anchor_protrusion < 3.0)
	assert(anchor_socket.y < stowed_anchor_top.y)

	var ground := Vector2(25.0, 420.0)
	assert(visual.clamp_ground_offset == Vector2(0.0, 2.0))
	assert(
		visual.get_ground_clamp_bottom_for_tests(ground).is_equal_approx(
			ground + Vector2(0.0, 2.0)
		)
	)
	var ground_clamp_rect: Rect2 = visual.get_ground_clamp_rect_for_tests(ground)
	var clamp_socket: Vector2 = visual.get_clamp_chain_socket_for_tests(ground)
	assert(ground_clamp_rect.position.y < ground.y)
	assert(ground_clamp_rect.end.y > ground.y)
	assert(is_equal_approx(ground_clamp_rect.end.y - ground.y, 2.0))
	assert(clamp_socket.is_equal_approx(Vector2(
		ground_clamp_rect.position.x + ground_clamp_rect.size.x * 0.5,
		ground_clamp_rect.position.y
	)))
	assert(visual.get_clamp_connection_point_for_tests(ground).y > clamp_socket.y)
	assert(is_equal_approx(visual.get_anchor_chain_attach_depth_for_tests(), 14.0))

	assert(combat_system.upgrades.apply_flag(CombatAnchorUpgradeRuntime.TRAP))
	assert(visual.get_winch_asset_id_for_tests() == &"trap")
	assert(
		visual._get_winch_texture(0).resource_path
		== "res://visual/objects/asset_winch_04.png"
	)
	var trap_winch_size: Vector2 = visual.get_winch_visual_size_for_tests(0)
	assert(trap_winch_size.is_equal_approx(Vector2(51.43467, 32.88264)))
	assert(trap_winch_size.x > platform.balance.cell_width)
	assert(visual.is_winch_drawable_for_tests(0))

	print("Anchor asset visual connection scenarios passed")
	quit()


func _is_operator_available(_side: int) -> bool:
	return true


func _is_simulation_active() -> bool:
	return true
