extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var animation := CharacterAnimationController.new()
	animation.play(&"idle", 4, 4.0)
	assert(animation.get_state_id() == &"idle")
	assert(animation.get_frame_index() == 0)
	animation.tick(0.25)
	assert(animation.get_frame_index() == 1)
	animation.tick(0.75)
	assert(animation.get_frame_index() == 0)

	animation.face_delta(-10.0)
	assert(not animation.is_facing_right())
	animation.face_delta(20.0)
	assert(animation.is_facing_right())

	animation.play(&"attack", 6, 10.0, false, true)
	animation.set_normalized_progress(0.5)
	assert(animation.get_frame_index() in [2, 3])
	animation.set_normalized_progress(1.0)
	assert(animation.get_frame_index() == 5)
	assert(animation.is_finished())

	animation.play(&"death", 2, 5.0, false, true)
	assert(not animation.is_finished())
	animation.tick(0.2)
	assert(animation.get_frame_index() == 1)
	assert(not animation.is_finished())
	animation.tick(0.2)
	assert(animation.is_finished())

	animation.play(&"run", 3, 6.0, true, true)
	animation.tick(1.0 / 6.0)
	assert(animation.get_frame_index() == 1)
	animation.play(&"run", 3, 6.0)
	assert(animation.get_frame_index() == 1)
	animation.play(&"run", 3, 6.0, true, true)
	assert(animation.get_frame_index() == 0)

	print("Character animation controller scenarios passed")
	quit()
