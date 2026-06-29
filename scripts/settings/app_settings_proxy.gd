class_name AppSettings
extends RefCounted


static func get_sound_ids() -> Array[StringName]:
	return _service().get_sound_ids()


static func get_sound_label(sound_id: StringName) -> String:
	return _service().get_sound_label(sound_id)


static func get_action_specs() -> Array[Dictionary]:
	return _service().get_action_specs()


static func get_effects_volume() -> float:
	return _service().get_effects_volume()


static func get_music_volume() -> float:
	return _service().get_music_volume()


static func get_sound_volume(sound_id: StringName) -> float:
	return _service().get_sound_volume(sound_id)


static func set_effects_volume(value: float, save: bool = true) -> void:
	_service().set_effects_volume(value, save)


static func set_music_volume(value: float, save: bool = true) -> void:
	_service().set_music_volume(value, save)


static func set_sound_volume(
	sound_id: StringName,
	value: float,
	save: bool = true
) -> void:
	_service().set_sound_volume(sound_id, value, save)


static func get_binding_key(action_id: StringName) -> int:
	return _service().get_binding_key(action_id)


static func get_binding_text(action_id: StringName) -> String:
	return _service().get_binding_text(action_id)


static func rebind_action(
	action_id: StringName,
	keycode: int,
	save: bool = true
) -> bool:
	return _service().rebind_action(action_id, keycode, save)


static func reset_audio_defaults(save: bool = true) -> void:
	_service().reset_audio_defaults(save)


static func reset_input_defaults(save: bool = true) -> void:
	_service().reset_input_defaults(save)


static func _service() -> AppSettingsService:
	var tree := Engine.get_main_loop() as SceneTree
	assert(tree != null, "AppSettings requires an active SceneTree")
	var service := tree.root.get_node_or_null("AppSettingsRuntime") as AppSettingsService
	assert(service != null, "AppSettingsRuntime autoload is missing")
	return service
