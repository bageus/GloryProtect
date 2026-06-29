class_name AppSettingsService
extends Node

signal audio_settings_changed
signal input_bindings_changed

const SETTINGS_PATH := "user://settings.cfg"
const EFFECTS_BUS := &"Effects"
const MUSIC_BUS := &"Music"
const DEFAULT_EFFECTS_VOLUME: float = 1.0
const DEFAULT_MUSIC_VOLUME: float = 0.75

const SOUND_IDS: Array[StringName] = [
	&"shield_charge",
	&"shield_alert",
	&"shield_wave",
	&"defender_attack",
	&"defender_die",
	&"healer_heal",
	&"monster_die",
	&"platform_move",
	&"shooter_attack",
	&"portal",
	&"turret_attack",
	&"winch_connect",
	&"winch_disconnect",
]

const SOUND_LABELS: Dictionary = {
	&"shield_charge": "Зарядка щита",
	&"shield_alert": "Критический щит",
	&"shield_wave": "Энергетическая волна",
	&"defender_attack": "Удар защитника",
	&"defender_die": "Гибель защитника",
	&"healer_heal": "Лечение",
	&"monster_die": "Гибель врага",
	&"platform_move": "Движение платформы",
	&"shooter_attack": "Выстрел стрелка",
	&"portal": "Портал и замена",
	&"turret_attack": "Выстрел турели",
	&"winch_connect": "Установка якоря",
	&"winch_disconnect": "Снятие или разрыв якоря",
}

const ACTION_SPECS: Array[Dictionary] = [
	{"id": &"gp_move_left", "label": "Движение влево", "key": KEY_LEFT, "group": "Платформа"},
	{"id": &"gp_move_right", "label": "Движение вправо", "key": KEY_RIGHT, "group": "Платформа"},
	{"id": &"gp_anchor_1", "label": "Якорь 1", "key": KEY_1, "group": "Якоря"},
	{"id": &"gp_anchor_2", "label": "Якорь 2", "key": KEY_2, "group": "Якоря"},
	{"id": &"gp_anchor_3", "label": "Якорь 3", "key": KEY_3, "group": "Якоря"},
	{"id": &"gp_anchor_4", "label": "Якорь 4", "key": KEY_4, "group": "Якоря"},
	{"id": &"gp_anchor_remove_all", "label": "Снять все якоря", "key": KEY_R, "group": "Якоря"},
	{"id": &"gp_select_defender_1", "label": "Выбрать защитника 1", "key": KEY_5, "group": "Экипаж"},
	{"id": &"gp_select_defender_2", "label": "Выбрать защитника 2", "key": KEY_6, "group": "Экипаж"},
	{"id": &"gp_select_defender_3", "label": "Выбрать защитника 3", "key": KEY_7, "group": "Экипаж"},
	{"id": &"gp_assign_driver", "label": "Назначить рулевого", "key": KEY_D, "group": "Экипаж"},
	{"id": &"gp_assign_left_anchor", "label": "Назначить левого якорщика", "key": KEY_Z, "group": "Экипаж"},
	{"id": &"gp_assign_right_anchor", "label": "Назначить правого якорщика", "key": KEY_X, "group": "Экипаж"},
	{"id": &"gp_assign_free", "label": "Назначить свободного бойца", "key": KEY_C, "group": "Экипаж"},
	{"id": &"gp_assign_medic", "label": "Назначить лекаря", "key": KEY_H, "group": "Экипаж"},
	{"id": &"gp_cell_previous", "label": "Предыдущая клетка", "key": KEY_COMMA, "group": "Объекты"},
	{"id": &"gp_cell_next", "label": "Следующая клетка", "key": KEY_PERIOD, "group": "Объекты"},
	{"id": &"gp_unlock_medical", "label": "Открыть пост лекаря", "key": KEY_B, "group": "Объекты"},
	{"id": &"gp_place_medical", "label": "Поставить пост лекаря", "key": KEY_M, "group": "Объекты"},
	{"id": &"gp_demolish_medical", "label": "Убрать пост лекаря", "key": KEY_DELETE, "group": "Объекты"},
	{"id": &"gp_unlock_turret", "label": "Открыть турель", "key": KEY_T, "group": "Турели"},
	{"id": &"gp_place_turret", "label": "Поставить турель", "key": KEY_G, "group": "Турели"},
	{"id": &"gp_cycle_turret", "label": "Выбрать следующую турель", "key": KEY_K, "group": "Турели"},
	{"id": &"gp_move_turret", "label": "Перенести турель", "key": KEY_V, "group": "Турели"},
	{"id": &"gp_assign_turret", "label": "Назначить оператора турели", "key": KEY_J, "group": "Турели"},
	{"id": &"gp_demolish_turret", "label": "Убрать турель", "key": KEY_BACKSPACE, "group": "Турели"},
	{"id": &"gp_shield_section_1", "label": "Тестовая секция щита 1", "key": KEY_F1, "group": "Debug"},
	{"id": &"gp_shield_section_2", "label": "Тестовая секция щита 2", "key": KEY_F2, "group": "Debug"},
	{"id": &"gp_shield_section_3", "label": "Тестовая секция щита 3", "key": KEY_F3, "group": "Debug"},
	{"id": &"gp_shield_section_4", "label": "Тестовая секция щита 4", "key": KEY_F4, "group": "Debug"},
	{"id": &"gp_shield_section_5", "label": "Тестовая секция щита 5", "key": KEY_F5, "group": "Debug"},
	{"id": &"gp_shield_damage", "label": "Тестовый урон щиту", "key": KEY_SPACE, "group": "Debug"},
]

var _settings_path: String = SETTINGS_PATH
var _effects_volume: float = DEFAULT_EFFECTS_VOLUME
var _music_volume: float = DEFAULT_MUSIC_VOLUME
var _sound_volumes: Dictionary[StringName, float] = {}
var _binding_keys: Dictionary[StringName, Key] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initialize_defaults()
	load_settings()


func get_sound_ids() -> Array[StringName]:
	return SOUND_IDS.duplicate()


func get_sound_label(sound_id: StringName) -> String:
	return String(SOUND_LABELS.get(sound_id, String(sound_id)))


func get_action_specs() -> Array[Dictionary]:
	return ACTION_SPECS.duplicate(true)


func get_effects_volume() -> float:
	return _effects_volume


func get_music_volume() -> float:
	return _music_volume


func get_sound_volume(sound_id: StringName) -> float:
	return float(_sound_volumes.get(sound_id, 1.0))


func set_effects_volume(value: float, save: bool = true) -> void:
	_effects_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volumes()
	audio_settings_changed.emit()
	if save:
		save_settings()


func set_music_volume(value: float, save: bool = true) -> void:
	_music_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volumes()
	audio_settings_changed.emit()
	if save:
		save_settings()


func set_sound_volume(sound_id: StringName, value: float, save: bool = true) -> void:
	if not SOUND_IDS.has(sound_id):
		return
	_sound_volumes[sound_id] = clampf(value, 0.0, 1.0)
	audio_settings_changed.emit()
	if save:
		save_settings()


func get_binding_key(action_id: StringName) -> Key:
	return _binding_keys.get(action_id, KEY_NONE) as Key


func get_binding_text(action_id: StringName) -> String:
	var keycode: Key = get_binding_key(action_id)
	return "Не назначено" if keycode == KEY_NONE else OS.get_keycode_string(keycode)


func rebind_action(action_id: StringName, keycode: Key, save: bool = true) -> bool:
	if not _has_action_spec(action_id) or keycode == KEY_NONE:
		return false
	_binding_keys[action_id] = keycode
	_apply_action_binding(action_id, keycode)
	input_bindings_changed.emit()
	if save:
		save_settings()
	return true


func reset_audio_defaults(save: bool = true) -> void:
	_effects_volume = DEFAULT_EFFECTS_VOLUME
	_music_volume = DEFAULT_MUSIC_VOLUME
	for sound_id: StringName in SOUND_IDS:
		_sound_volumes[sound_id] = 1.0
	_apply_bus_volumes()
	audio_settings_changed.emit()
	if save:
		save_settings()


func reset_input_defaults(save: bool = true) -> void:
	for spec: Dictionary in ACTION_SPECS:
		var action_id: StringName = spec["id"]
		var keycode: Key = spec["key"]
		_binding_keys[action_id] = keycode
		_apply_action_binding(action_id, keycode)
	input_bindings_changed.emit()
	if save:
		save_settings()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "effects", _effects_volume)
	config.set_value("audio", "music", _music_volume)
	for sound_id: StringName in SOUND_IDS:
		config.set_value("sound", String(sound_id), get_sound_volume(sound_id))
	for spec: Dictionary in ACTION_SPECS:
		var action_id: StringName = spec["id"]
		config.set_value("input", String(action_id), int(get_binding_key(action_id)))
	config.save(_settings_path)


func load_settings() -> void:
	_initialize_defaults()
	var config := ConfigFile.new()
	if config.load(_settings_path) == OK:
		_effects_volume = clampf(float(config.get_value("audio", "effects", _effects_volume)), 0.0, 1.0)
		_music_volume = clampf(float(config.get_value("audio", "music", _music_volume)), 0.0, 1.0)
		for sound_id: StringName in SOUND_IDS:
			_sound_volumes[sound_id] = clampf(float(config.get_value("sound", String(sound_id), 1.0)), 0.0, 1.0)
		for spec: Dictionary in ACTION_SPECS:
			var action_id: StringName = spec["id"]
			var default_key: Key = spec["key"]
			_binding_keys[action_id] = int(config.get_value("input", String(action_id), int(default_key))) as Key
	_apply_all()


func set_settings_path_for_tests(path: String) -> void:
	_settings_path = path


func _initialize_defaults() -> void:
	_effects_volume = DEFAULT_EFFECTS_VOLUME
	_music_volume = DEFAULT_MUSIC_VOLUME
	_sound_volumes.clear()
	_binding_keys.clear()
	for sound_id: StringName in SOUND_IDS:
		_sound_volumes[sound_id] = 1.0
	for spec: Dictionary in ACTION_SPECS:
		_binding_keys[spec["id"]] = spec["key"]


func _apply_all() -> void:
	_ensure_audio_bus(EFFECTS_BUS)
	_ensure_audio_bus(MUSIC_BUS)
	_apply_bus_volumes()
	for spec: Dictionary in ACTION_SPECS:
		var action_id: StringName = spec["id"]
		_apply_action_binding(action_id, get_binding_key(action_id))
	audio_settings_changed.emit()
	input_bindings_changed.emit()


func _ensure_audio_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _apply_bus_volumes() -> void:
	_ensure_audio_bus(EFFECTS_BUS)
	_ensure_audio_bus(MUSIC_BUS)
	_set_bus_linear_volume(EFFECTS_BUS, _effects_volume)
	_set_bus_linear_volume(MUSIC_BUS, _music_volume)


func _set_bus_linear_volume(bus_name: StringName, value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(bus_index, value <= 0.0001)


func _apply_action_binding(action_id: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id)
	InputMap.action_erase_events(action_id)
	if keycode == KEY_NONE:
		return
	var input_event := InputEventKey.new()
	input_event.physical_keycode = keycode
	InputMap.action_add_event(action_id, input_event)


func _has_action_spec(action_id: StringName) -> bool:
	for spec: Dictionary in ACTION_SPECS:
		if spec["id"] == action_id:
			return true
	return false
