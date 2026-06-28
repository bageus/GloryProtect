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
	visual.configure(
		AnchorRuntimeStore.new(),
		geometry,
		anchor_balance,
		Callable(self, "_always_true"),
		Callable(self, "_always_true")
	)

	var surface_y: float = geometry.get_platform_surface_world_y()
	var physical_attachment_y: float = (
		geometry.get_platform_attachment_world(0).y
	)
	var visual_bottom: Vector2 = visual.get_winch_visual_bottom(0)
	assert(is_equal_approx(surface_y, 271.0))
	assert(is_equal_approx(visual_bottom.y, 276.0))
	assert(visual_bottom.y < physical_attachment_y)
	assert(is_equal_approx(physical_attachment_y, 326.1))
	assert(is_equal_approx(visual.get_clamp_visual_scale(), 0.156))
	print("Anchor visual geometry scenarios passed")
	quit()


func _always_true() -> bool:
	return true
