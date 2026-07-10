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

	assert(is_equal_approx(visual.get_winch_scale_multiplier_for_tests(), 0.70))
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

	var base_winch_source: Rect2 = visual._get_winch_source_rect(0)
	var base_winch_size: Vector2 = (
		base_winch_source.size
		* visual.object_asset_scale
		* visual.get_winch_scale_multiplier_for_tests()
	)
	assert(base_winch_size.is_equal_approx(Vector2(57.82, 33.74)))
	assert(
		visual.get_winch_chain_exit(0).is_equal_approx(
			visual.get_winch_visual_bottom(0) + Vector2(7.0, -3.0)
		)
	)
	assert(
		visual.get_winch_chain_exit(3).is_equal_approx(
			visual.get_winch_visual_bottom(3) + Vector2(-7.0, -3.0)
		)
	)

	var ground := Vector2(25.0, 420.0)
	assert(visual.clamp_ground_offset == Vector2(0.0, 2.0))
	assert(
		visual.get_clamp_connection_point_for_tests(ground).is_equal_approx(
			ground
			+ visual.clamp_ground_offset
			+ visual.clamp_chain_connection_offset
		)
	)
	assert(is_equal_approx(visual.get_anchor_chain_attach_depth_for_tests(), 8.0))

	assert(combat_system.upgrades.apply_flag(CombatAnchorUpgradeRuntime.TRAP))
	assert(visual.get_winch_asset_id_for_tests() == &"trap")
	assert(
		visual._get_winch_texture(0).resource_path
		== "res://visual/objects/asset_winch_04.png"
	)
	var trap_winch_size: Vector2 = (
		visual.get_trap_winch_source_rect_for_tests().size
		* visual.object_asset_scale
		* visual.get_winch_scale_multiplier_for_tests()
	)
	assert(trap_winch_size.is_equal_approx(Vector2(64.82, 41.44)))
	assert(visual.is_winch_drawable_for_tests(0))

	print("Anchor asset visual connection scenarios passed")
	quit()


func _is_operator_available(_side: int) -> bool:
	return true


func _is_simulation_active() -> bool:
	return true
