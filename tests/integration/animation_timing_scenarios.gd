extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var defender: Defender = crew.get_defender(0)
	var platform_visual: PlatformVisualController = game.get_node("World/Platform/PlatformVisualController")
	var ground_visual: GroundOrbVisualController = game.get_node("World/GroundOrbVisualController")
	assert(is_equal_approx(defender.visual.run_frame_rate, 7.0))
	assert(is_equal_approx(defender.visual.idle_frame_rate, 6.0))
	assert(is_equal_approx(defender.visual.attack_frame_rate, 12.0))
	assert(is_equal_approx(defender.visual.death_frame_rate, 6.0))
	assert(is_equal_approx(platform_visual.platform_core_frame_rate, 4.0))
	assert(is_equal_approx(ground_visual.ground_core_frame_rate, 4.0))
	print("Animation timing scenarios passed")
	quit()
