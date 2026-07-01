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

	var visual := AnchorVisualController.new()
	visual.object_asset_scale = 0.12
	visual.clamp_scale_multiplier = 1.30
	visual.winch_embed_depth = 5.0
	visual.winch_chain_exit_offset = Vector2(7.0, -3.0)
	visual.configure(
		AnchorRuntimeStore.new(),
		geometry,
		anchor_balance,
		Callable(self, "_always_true"),
		Callable(self, "_always_true")
	)

	var surface_y: float = geometry.get_platform_surface_world_y()
	var physical_attachment: Vector2 = (
		geometry.get_platform_attachment_world(0)
	)
	var left_bottom: Vector2 = visual.get_winch_visual_bottom(0)
	var left_exit: Vector2 = visual.get_winch_chain_exit(0)
	var mirrored_exit: Vector2 = visual.get_winch_chain_exit(1)
	assert(is_equal_approx(surface_y, 271.0))
	assert(is_equal_approx(left_bottom.y, 276.0))
	assert(left_bottom.y < physical_attachment.y)
	assert(is_equal_approx(physical_attachment.y, 326.1))
	assert(left_exit.is_equal_approx(left_bottom + Vector2(7.0, -3.0)))
	assert(
		mirrored_exit.is_equal_approx(
			visual.get_winch_visual_bottom(1) + Vector2(-7.0, -3.0)
		)
	)
	assert(not left_exit.is_equal_approx(physical_attachment))
	assert(is_equal_approx(visual.get_clamp_visual_scale(), 0.156))

	var original_exit := visual.get_winch_chain_exit(2)
	platform.position.x += 120.0
	var moved_exit := visual.get_winch_chain_exit(2)
	assert(
		moved_exit.is_equal_approx(original_exit + Vector2(120.0, 0.0))
	)

	var chain_links := AnchorVisualController.calculate_chain_link_positions(
		Vector2(10.0, 20.0),
		Vector2(90.0, 60.0),
		12.0
	)
	assert(chain_links.size() >= 2)
	assert(chain_links[0].is_equal_approx(Vector2(10.0, 20.0)))
	assert(
		chain_links[chain_links.size() - 1].is_equal_approx(
			Vector2(90.0, 60.0)
		)
	)
	for index: int in range(1, chain_links.size()):
		assert(
			chain_links[index].distance_to(chain_links[index - 1]) <= 12.01
		)

	print("Anchor visual geometry scenarios passed")
	quit()


func _always_true() -> bool:
	return true
