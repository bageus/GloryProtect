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

	assert(is_equal_approx(visual.get_winch_scale_multiplier_for_tests(), 0.483))
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
	assert(base_winch_size.is_equal_approx(Vector2(39.8958, 23.2806)))
	assert(base_winch_size.x <= platform.balance.cell_width)
	var left_winch_bottom: Vector2 = visual.get_winch_visual_bottom(0)
	var right_winch_bottom: Vector2 = visual.get_winch_visual_bottom(3)
	assert(
		visual.get_winch_chain_exit(0).is_equal_approx(
			left_winch_bottom + Vector2(0.0, -base_winch_size.y * 0.5)
		)
	)
	assert(
		visual.get_winch_chain_exit(3).is_equal_approx(
			right_winch_bottom + Vector2(0.0, -base_winch_size.y * 0.5)
		)
	)
	var left_exit: Vector2 = visual.get_winch_chain_exit(0)
	assert(left_exit.y > left_winch_bottom.y - base_winch_size.y)
	assert(left_exit.y < left_winch_bottom.y)

	var platform_bottom_y: float = (
		platform.position.y + platform.balance.platform_height * 0.5
	)
	var stowed_anchor_rect: Rect2 = visual.get_stowed_anchor_rect_for_tests(0)
	assert(stowed_anchor_rect.end.y > platform_bottom_y)
	assert(stowed_anchor_rect.end.y - platform_bottom_y < 8.0)

	var ground := Vector2(25.0, 420.0)
	assert(visual.clamp_ground_offset == Vector2(0.0, 2.0))
	assert(
		visual.get_ground_clamp_bottom_for_tests(ground).is_equal_approx(
			ground + Vector2(0.0, 2.0)
		)
	)
	var ground_clamp_rect: Rect2 = visual.get_ground_clamp_rect_for_tests(ground)
	assert(ground_clamp_rect.position.y < ground.y)
	assert(ground_clamp_rect.end.y > ground.y)
	assert(is_equal_approx(ground_clamp_rect.end.y - ground.y, 2.0))
	assert(
		visual.get_clamp_connection_point_for_tests(ground).is_equal_approx(
			ground
			+ visual.clamp_ground_offset
			+ visual.clamp_chain_connection_offset
		)
	)
	assert(is_equal_approx(visual.get_anchor_chain_attach_depth_for_tests(), 14.0))

	assert(combat_system.upgrades.apply_flag(CombatAnchorUpgradeRuntime.TRAP))
	assert(visual.get_winch_asset_id_for_tests() == &"trap")
	assert(
		visual._get_winch_texture(0).resource_path
		== "res://visual/objects/asset_winch_04.png"
	)
	var trap_winch_size: Vector2 = visual.get_winch_visual_size_for_tests(0)
	assert(trap_winch_size.is_equal_approx(Vector2(44.7258, 28.5936)))
	assert(trap_winch_size.x > platform.balance.cell_width)
	assert(visual.is_winch_drawable_for_tests(0))

	print("Anchor asset visual connection scenarios passed")
	quit()


func _is_operator_available(_side: int) -> bool:
	return true


func _is_simulation_active() -> bool:
	return true
