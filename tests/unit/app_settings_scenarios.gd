extends SceneTree

const TEST_PATH := "user://app_settings_scenarios.cfg"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_file()
	var settings := AppSettingsService.new()
	root.add_child(settings)
	await process_frame
	settings.set_settings_path_for_tests(TEST_PATH)
	settings.reset_audio_defaults(false)
	settings.reset_input_defaults(false)
	settings.set_effects_volume(0.42, false)
	settings.set_music_volume(0.31, false)
	settings.set_sound_volume(&"turret_attack", 0.27, false)
	assert(settings.rebind_action(&"gp_move_left", KEY_A, false))
	settings.save_settings()

	settings.reset_audio_defaults(false)
	settings.reset_input_defaults(false)
	assert(not is_equal_approx(settings.get_effects_volume(), 0.42))
	assert(settings.get_binding_key(&"gp_move_left") == KEY_LEFT)
	settings.load_settings()

	assert(is_equal_approx(settings.get_effects_volume(), 0.42))
	assert(is_equal_approx(settings.get_music_volume(), 0.31))
	assert(is_equal_approx(settings.get_sound_volume(&"turret_attack"), 0.27))
	assert(settings.get_binding_key(&"gp_move_left") == KEY_A)
	assert(settings.get_sound_ids().size() == 13)
	assert(AudioServer.get_bus_index(AppSettingsService.EFFECTS_BUS) >= 0)
	assert(AudioServer.get_bus_index(AppSettingsService.MUSIC_BUS) >= 0)

	var events: Array[InputEvent] = InputMap.action_get_events(&"gp_move_left")
	assert(events.size() == 1)
	var key_event := events[0] as InputEventKey
	assert(key_event != null)
	assert(key_event.physical_keycode == KEY_A)

	settings.queue_free()
	AppSettings.reset_audio_defaults(false)
	AppSettings.reset_input_defaults(false)
	_remove_test_file()
	print("App settings scenarios passed")
	quit()


func _remove_test_file() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(TEST_PATH)
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(absolute_path)
