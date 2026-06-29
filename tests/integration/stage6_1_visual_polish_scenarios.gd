extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.state = GameFlowController.RunState.RUNNING
	_disable_spawners(game)

	var platform_visual := game.get_node(
		"World/Platform/PlatformVisualController"
	) as PlatformVisualControllerPolished
	var buildable_visual := game.get_node(
		"World/Platform/BuildableGridVisual"
	) as BuildableGridVisualPolished
	var anchors := game.get_node(
		"World/AnchorSystem"
	) as CombatAnchorHostSystem
	var minimap := game.get_node(
		"CanvasLayer/StrategicMinimap"
	) as StrategicMinimapPolished
	var roles := game.get_node(
		"World/Platform/CrewRoleManager"
	) as ShooterCrewRoleManagerPolished
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")

	assert(platform_visual != null)
	assert(platform_visual.has_empty_console_asset())
	assert(is_equal_approx(
		roles.get_role_target_x(CrewRole.Id.DRIVER),
		platform_visual.driver_console_surface_offset.x
	))
	var two_cell_width: float = platform_visual.balance.cell_width * 2.0
	assert(platform_visual.get_occupied_console_max_width() < two_cell_width)
	for steering_axis: float in [-1.0, 0.0, 1.0]:
		var console_size: Vector2 = (
			platform_visual.get_occupied_console_size_for_axis(steering_axis)
		)
		assert(console_size.x <= two_cell_width + 0.01)
		assert(console_size.x <= platform_visual.get_occupied_console_max_width() + 0.01)
	assert(is_equal_approx(anchors.get_winch_vertical_offset(), 0.0))
	assert(is_equal_approx(buildable_visual.medical_post_scale, 0.18))
	assert(is_equal_approx(buildable_visual.turret_asset_scale, 0.095))
	assert(minimap.cloud_morph_speed >= 2.0)
	assert(minimap.get_cloud_radius(9).x > 22.0)

	var driver: Defender = crew.get_defender(0)
	var driver_visual := driver.visual as DefenderVisualPolished
	assert(driver_visual != null)
	assert(driver_visual.get_health_bar_raise() >= 30.0)

	roles.request_assignment(0, CrewRole.Id.FREE_FIGHTER)
	await _wait_for_role(roles, 0, CrewRole.Id.FREE_FIGHTER)
	assert(driver_visual.get_health_bar_raise() == 0.0)

	print("Stage 6.1 visual polish scenarios passed")
	quit()


func _wait_for_role(
	roles: CrewRoleManager,
	defender_id: int,
	role_id: int
) -> void:
	for _frame: int in range(360):
		var assignment: CrewAssignmentRuntime = roles.get_assignment(defender_id)
		if (
			assignment != null
			and assignment.current_role == role_id
			and assignment.state == CrewAssignmentRuntime.State.ACTIVE
		):
			return
		await physics_frame
	assert(false, "Defender did not reach requested role")


func _disable_spawners(game: Node) -> void:
	var paths: Array[NodePath] = [
		NodePath("World/BoardingSpawnDirector"),
		NodePath("World/FlyingEnemySpawnDirector"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
	]
	for path: NodePath in paths:
		if not game.has_node(path):
			continue
		var node: Node = game.get_node(path)
		node.set_process(false)
		node.set_physics_process(false)
