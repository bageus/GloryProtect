extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run_scenario")


func _run_scenario() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var visual: BuildableGridVisual = game.get_node(
		"World/Platform/BuildableGridVisual"
	)
	var medical: MedicalStationSystem = game.get_node(
		"World/MedicalStationSystem"
	)
	assert(not visual.is_medical_cycle_visual_active())
	assert(is_zero_approx(visual.get_medical_cycle_progress()))

	medical.healing_started.emit(0, 1)
	medical.healing_progress.emit(0, 1, 4.0)
	assert(visual.is_medical_cycle_visual_active())
	assert(is_zero_approx(visual.get_medical_cycle_progress()))

	medical.healing_progress.emit(0, 1, 2.0)
	assert(is_equal_approx(visual.get_medical_cycle_progress(), 0.5))

	medical.segment_restored.emit(0, 1, 1)
	medical.healing_stopped.emit(0, 1)
	assert(not visual.is_medical_cycle_visual_active())
	var flash_before_pause := visual.get_medical_flash_remaining()
	assert(flash_before_pause > 0.0)

	paused = true
	await create_timer(0.1, true).timeout
	assert(is_equal_approx(
		visual.get_medical_flash_remaining(),
		flash_before_pause
	))
	paused = false
	visual._process(0.05)
	assert(visual.get_medical_flash_remaining() < flash_before_pause)

	print("Buildable state presentation scenarios passed")
	quit()
