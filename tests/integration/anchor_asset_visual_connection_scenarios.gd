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
	assert(
		visual.get_base_anchor_source_rect_for_tests()
		== Rect2(Vector2(157.0, 162.0), Vector2(198.0, 252.0))
	)
	assert(
		visual.get_base_clamp_source_rect_for_tests()
		== Rect2(Vector2(169.0, 188.0), Vector2(173.0, 174.0))
	)
	assert(
		visual.get_trap_winch_source_rect_for_tests()
		== Rect2(Vector2(36.0, 108.0), Vector2(463.0, 296.0))
	)

	var base_winch_size: Vector2 = visual.get_winch_visual_size_for_tests(0)
	assert(base_winch_size.is_equal_approx(Vector2(39.8958, 23.2806)))
	assert(base_winch_size.x > 34.692)
	assert(
		visual.get_winch_chain_exit(0).is_equal_approx(
			visual.get_winch_visual_bottom(0)
			+ Vector2(0.0, -base_winch_size.y * 0.5)
		)
	)
	assert(
		visual.get_winch_chain_exit(3).is_equal_approx(
			visual.get_winch_visual_bottom(3)
			+ Vector2(0.0, -base_winch_size.y * 0.5)
		)
	)

	var ground := Vector2(25.0, 420.0)
	assert(visual.clamp_ground_offset == Vector2(0.0, 40.0))
	assert(
		visual.get_ground_clamp_bottom_for_tests(ground).is_equal_approx(
			ground + Vector2(0.0, 40.0)
		)
	)
	var base_clamp_top: Vector2 = visual.get_clamp_top_for_tests(ground)
	assert(base_clamp_top.y > ground.y)
	assert(
		visual.get_clamp_connection_point_for_tests(ground).is_equal_approx(
			base_clamp_top + Vector2(0.0, 6.0)
		)
	)
	assert(is_equal_approx(visual.get_anchor_chain_attach_depth_for_tests(), 20.0))

	assert(combat_system.upgrades.apply_flag(CombatAnchorUpgradeRuntime.TRAP))
	assert(visual.get_winch_asset_id_for_tests() == &"trap")
	assert(
		visual._get_winch_texture(0).resource_path
		== "res://visual/objects/asset_winch_04.png"
	)
	var trap_winch_size: Vector2 = visual.get_winch_visual_size_for_tests(0)
	assert(trap_winch_size.is_equal_approx(Vector2(44.7258, 28.5936)))
	assert(trap_winch_size.x > 38.892)
	assert(visual.is_winch_drawable_for_tests(0))

	combat_system.upgrades.reset()
	assert(combat_system.upgrades.apply_scalar(
		CombatAnchorUpgradeRuntime.INSTALL_SPEED_BONUS_RATIO,
		0.4
	))
	var turbo_clamp_top: Vector2 = visual.get_clamp_top_for_tests(ground)
	assert(
		visual.get_turbo_anchor_bottom_for_tests(ground).is_equal_approx(
			turbo_clamp_top
		)
	)
	assert(
		visual.get_clamp_connection_point_for_tests(ground).y
		< turbo_clamp_top.y
	)

	print("Anchor asset visual connection scenarios passed")
	quit()


func _is_operator_available(_side: int) -> bool:
	return true


func _is_simulation_active() -> bool:
	return true
