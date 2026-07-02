extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var background := game.get_node(
		"ParallaxSceneBackground"
	) as ParallaxSceneBackground
	var platform := game.get_node("World/Platform") as PlatformController
	assert(background != null)
	assert(platform != null)

	var far_before: Vector2 = background.get_far_layer_position()
	var near_before: Vector2 = background.get_near_layer_position()
	assert(is_equal_approx(background.get_near_layer_vertical_offset(), 1.0))
	assert(is_equal_approx(
		near_before.y - far_before.y,
		background.get_near_layer_vertical_offset()
	))

	var platform_y_before: float = platform.position.y
	platform.position.x += 128.0
	await process_frame
	var far_after: Vector2 = background.get_far_layer_position()
	var near_after: Vector2 = background.get_near_layer_position()
	assert(is_equal_approx(platform.position.y, platform_y_before))
	assert(is_equal_approx(
		near_after.y - far_after.y,
		background.get_near_layer_vertical_offset()
	))
	assert(not is_equal_approx(near_after.x, near_before.x))
	assert(not is_equal_approx(far_after.x, far_before.x))

	print("Parallax scene background scenarios passed")
	quit()
