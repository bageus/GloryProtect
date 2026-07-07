extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var first_game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(first_game)
	await process_frame
	await process_frame

	var first_background := first_game.get_node(
		"ParallaxSceneBackground"
	) as ParallaxSceneBackground
	var first_platform := first_game.get_node("World/Platform") as PlatformController
	assert(first_background != null)
	assert(first_platform != null)
	_assert_single_visible_scene(first_background)

	var position_before: Vector2 = (
		first_background.get_active_scene_position_for_tests()
	)
	var platform_y_before: float = first_platform.position.y
	first_platform.position.x += 128.0
	await process_frame
	var position_after: Vector2 = (
		first_background.get_active_scene_position_for_tests()
	)
	assert(is_equal_approx(first_platform.position.y, platform_y_before))
	assert(not is_equal_approx(position_after.x, position_before.x))
	assert(is_equal_approx(position_after.y, position_before.y))

	first_game.queue_free()
	await process_frame

	var second_game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(second_game)
	await process_frame
	await process_frame
	var second_background := second_game.get_node(
		"ParallaxSceneBackground"
	) as ParallaxSceneBackground
	assert(second_background != null)
	_assert_single_visible_scene(second_background)

	print("Parallax scene background scenarios passed")
	quit()


func _assert_single_visible_scene(background: ParallaxSceneBackground) -> void:
	assert(background.get_visible_scene_layer_count_for_tests() == 1)
	assert(is_equal_approx(
		background.get_scene_layer_alpha_for_tests(
			background.get_active_scene_index_for_tests()
		),
		1.0
	))
