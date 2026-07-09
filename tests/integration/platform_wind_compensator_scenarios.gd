extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	flow.state = GameFlowController.RunState.RUNNING
	_disable_spawners(game)

	var platform: PlatformController = game.get_node("World/Platform")
	var wind: WindSystem = game.get_node("WindSystem")
	var anchorless: AnchorlessControlSystem = game.get_node(
		"World/AnchorlessControlSystem"
	) as AnchorlessControlSystem
	var catalog: UpgradeCatalog = game.get_node("UpgradeSystem").catalog
	var compensator: PlatformWindCompensatorVisual = game.get_node(
		"World/Platform/PlatformWindCompensatorVisual"
	) as PlatformWindCompensatorVisual
	assert(platform != null)
	assert(wind != null)
	assert(anchorless != null)
	assert(catalog != null)
	assert(compensator != null)

	_assert_compensator_layout(compensator, platform)
	assert(compensator.z_index >= compensator.get_minimum_z_index_for_tests())
	assert(not compensator.z_as_relative)
	assert(not compensator.is_compensator_visible_for_tests())
	assert(not compensator.visible)
	assert(compensator.get_active_side_for_tests() == 0)

	_apply(anchorless, catalog, &"anchorless_wind_reduction_basic")
	await process_frame
	assert(compensator.is_compensator_visible_for_tests())
	assert(compensator.visible)
	assert(compensator.z_index >= 12)

	wind.set_debug_state(1, 2)
	await process_frame
	assert(compensator.get_active_side_for_tests() == 1)
	assert(not compensator.is_side_mirrored_for_tests(1))

	wind.set_debug_state(-1, 2)
	await process_frame
	assert(compensator.get_active_side_for_tests() == -1)
	assert(compensator.is_side_mirrored_for_tests(-1))

	wind.set_anchorless_modifiers(1.0, false)
	await process_frame
	assert(compensator.get_active_side_for_tests() == 0)
	wind.reset_anchorless_modifiers()

	anchorless.reset_upgrade_runtime()
	await process_frame
	assert(not compensator.is_compensator_visible_for_tests())
	assert(not compensator.visible)

	print("Platform wind compensator scenarios passed")
	quit()


func _apply(
	anchorless: AnchorlessControlSystem,
	catalog: UpgradeCatalog,
	card_id: StringName
) -> void:
	var definition: UpgradeDefinition = catalog.get_definition(card_id)
	assert(definition != null)
	assert(anchorless.can_apply_upgrade_effect(definition.effect))
	assert(anchorless.apply_upgrade_effect(definition.effect))


func _assert_compensator_layout(
	compensator: PlatformWindCompensatorVisual,
	platform: PlatformController
) -> void:
	var centers: Array[Vector2] = compensator.get_compensator_centers_for_tests()
	var left_center: Vector2 = centers[0]
	var right_center: Vector2 = centers[1]
	var draw_size: Vector2 = compensator.get_compensator_draw_size_for_tests()
	var platform_bottom: float = compensator.get_platform_bottom_y_for_tests()
	var left_inner_edge: float = compensator.get_anchor_post_inner_edge_x_for_tests(-1)
	var right_inner_edge: float = compensator.get_anchor_post_inner_edge_x_for_tests(1)

	assert(draw_size.x > 0.0)
	assert(draw_size.y > 0.0)
	assert(is_equal_approx(platform_bottom, platform.get_platform_height() * 0.5))
	assert(left_inner_edge < 0.0)
	assert(right_inner_edge > 0.0)
	assert(left_center.x > left_inner_edge)
	assert(right_center.x < right_inner_edge)
	assert(is_equal_approx(
		left_center.x - draw_size.x * 0.5,
		left_inner_edge + compensator.anchor_post_gap
	))
	assert(is_equal_approx(
		right_center.x + draw_size.x * 0.5,
		right_inner_edge - compensator.anchor_post_gap
	))
	assert(is_equal_approx(
		left_center.y - draw_size.y * 0.5,
		platform_bottom - compensator.platform_attach_overlap + compensator.vertical_offset
	))
	assert(is_equal_approx(
		right_center.y - draw_size.y * 0.5,
		platform_bottom - compensator.platform_attach_overlap + compensator.vertical_offset
	))
	assert(left_center.y + draw_size.y * 0.5 > platform_bottom)
	assert(right_center.y + draw_size.y * 0.5 > platform_bottom)
	assert(compensator.is_side_mirrored_for_tests(-1))
	assert(not compensator.is_side_mirrored_for_tests(1))


func _disable_spawners(game: Node) -> void:
	var paths: Array[NodePath] = [
		NodePath("World/BoardingSpawnDirector"),
		NodePath("World/FlyingEnemySpawnDirector"),
		NodePath("World/StrategicWaveSystem"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
	]
	for path: NodePath in paths:
		if not game.has_node(path):
			continue
		var node: Node = game.get_node(path)
		node.set_process(false)
		node.set_physics_process(false)
