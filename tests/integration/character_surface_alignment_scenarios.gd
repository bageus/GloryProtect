extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	flow.state = GameFlowController.RunState.RUNNING
	_disable_spawners(game)

	var platform: PlatformController = game.get_node("World/Platform")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var spawn: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	var orbs: GroundOrbRegistry = game.get_node("World/GroundOrbRegistry")

	var defender := crew.get_defender(0) as SurfaceAlignedDefender
	assert(defender != null)
	var platform_surface_local_y: float = -platform.get_platform_height() * 0.5
	assert(
		is_equal_approx(
			defender.get_visual_feet_platform_local_y(),
			platform_surface_local_y
		)
	)
	var defender_gameplay_y: float = defender.position.y
	defender.teleport_to(80.0)
	assert(is_equal_approx(defender.position.y, defender_gameplay_y))
	assert(
		is_equal_approx(
			defender.get_visual_feet_platform_local_y(),
			platform_surface_local_y
		)
	)

	var ground_contact_y: float = spawn.balance.ground_vertical_offset
	var platform_contact_y: float = (
		-platform.get_platform_height() * 0.5
		- spawn.balance.platform_local_y
	)
	assert(is_equal_approx(ground_contact_y, 12.0))
	assert(is_equal_approx(platform_contact_y, 19.0))

	await _check_enemy_archetype(
		spawn,
		orbs,
		platform,
		&"basic",
		-1,
		ground_contact_y,
		platform_contact_y
	)
	await _check_enemy_archetype(
		spawn,
		orbs,
		platform,
		&"runner",
		1,
		ground_contact_y,
		platform_contact_y
	)

	print("Character surface alignment scenarios passed")
	quit()


func _check_enemy_archetype(
	spawn: BoardingSpawnDirector,
	orbs: GroundOrbRegistry,
	platform: PlatformController,
	archetype_id: StringName,
	side: int,
	ground_contact_y: float,
	platform_contact_y: float
) -> void:
	var enemy: BoardingEnemy = spawn.spawn_debug_archetype(archetype_id, side)
	assert(enemy != null)
	var aligned := enemy as SurfaceAlignedBoardingEnemy
	var controller := enemy.controller as SurfaceAlignedBoardingEnemyController
	assert(aligned != null)
	assert(controller != null)
	controller.set_physics_process(false)

	assert(
		is_equal_approx(
			aligned.get_visual_surface_contact_local_y(),
			ground_contact_y
		)
	)
	assert(
		is_equal_approx(
			enemy.global_position.y,
			orbs.catalog.ground_y - spawn.balance.ground_vertical_offset
		)
	)
	assert(is_equal_approx(controller.get_ground_visual_contact_y(), ground_contact_y))
	assert(is_equal_approx(controller.get_platform_visual_contact_y(), platform_contact_y))
	assert(
		is_equal_approx(
			controller.get_climb_visual_contact_y(0.5),
			(ground_contact_y + platform_contact_y) * 0.5
		)
	)

	enemy.force_board_at(0.0)
	assert(enemy.is_on_platform())
	assert(
		is_equal_approx(
			aligned.get_visual_surface_contact_local_y(),
			platform_contact_y
		)
	)
	assert(
		is_equal_approx(
			enemy.global_position.y,
			platform.global_position.y + spawn.balance.platform_local_y
		)
	)

	var detached_visual: BoardingEnemyVisual = enemy.visual
	var visual_global_y: float = detached_visual.global_position.y
	enemy.kill(&"surface_alignment_test")
	assert(detached_visual.is_detached_death())
	assert(is_equal_approx(detached_visual.global_position.y, visual_global_y))
	await process_frame


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
