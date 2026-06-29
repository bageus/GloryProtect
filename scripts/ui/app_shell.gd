class_name AppShell
extends Node

const GAME_SCENE: PackedScene = preload(
	"res://scenes/game/game_root_with_flyers.tscn"
)

enum Screen {
	NONE,
	MAIN,
	PAUSE,
	SETTINGS_AUDIO,
	SETTINGS_CONTROLS,
}

var _active_game: Node2D
var _game_flow: GameFlowController
var _screen: int = Screen.MAIN
var _settings_return_screen: int = Screen.MAIN
var _waiting_action: StringName = &""
var _waiting_button: Button

var _game_host: Node
var _menu_layer: CanvasLayer
var _overlay: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _body: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"app_shell")
	_game_host = Node.new()
	_game_host.name = "GameHost"
	add_child(_game_host)
	_create_menu_ui()
	_show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if _waiting_action != &"":
		_handle_rebind_event(event)
		return
	if not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	match _screen:
		Screen.SETTINGS_AUDIO, Screen.SETTINGS_CONTROLS:
			_return_from_settings()
		Screen.PAUSE:
			_resume_run()
		Screen.MAIN:
			pass
		Screen.NONE:
			_open_pause_menu()


func start_new_game() -> void:
	if _active_game != null and is_instance_valid(_active_game):
		_resume_run()
		return
	_spawn_game()


func restart_active_run() -> void:
	get_tree().paused = false
	_waiting_action = &""
	_waiting_button = null
	if _active_game != null and is_instance_valid(_active_game):
		_game_host.remove_child(_active_game)
		_active_game.queue_free()
	_active_game = null
	_game_flow = null
	_screen = Screen.NONE
	_set_overlay_visible(false)
	call_deferred("_spawn_game")


func show_main_menu() -> void:
	if _game_flow != null and _game_flow.state != GameFlowController.RunState.GAME_OVER:
		if _game_flow.state != GameFlowController.RunState.MANUAL_PAUSE:
			_game_flow.toggle_manual_pause()
	_show_main_menu()


func get_active_game() -> Node2D:
	return _active_game


func get_current_screen() -> int:
	return _screen


func is_waiting_for_binding() -> bool:
	return _waiting_action != &""


func _spawn_game() -> void:
	_active_game = GAME_SCENE.instantiate() as Node2D
	_game_host.add_child(_active_game)
	_game_flow = _active_game.get_node("GameFlowController") as GameFlowController
	_game_flow.restart_requested.connect(_on_restart_requested)
	_game_flow.run_state_changed.connect(_on_run_state_changed)
	_screen = Screen.NONE
	_set_overlay_visible(false)


func _open_pause_menu() -> void:
	if _game_flow == null:
		return
	if _game_flow.state not in [
		GameFlowController.RunState.START_DELAY,
		GameFlowController.RunState.RUNNING,
	]:
		return
	_game_flow.toggle_manual_pause()
	_show_pause_menu()


func _resume_run() -> void:
	if _game_flow == null:
		return
	if _game_flow.state == GameFlowController.RunState.MANUAL_PAUSE:
		_game_flow.toggle_manual_pause()
	_screen = Screen.NONE
	_set_overlay_visible(false)


func _show_main_menu() -> void:
	_screen = Screen.MAIN
	_settings_return_screen = Screen.MAIN
	_set_overlay_visible(true)
	_clear_body()
	_title_label.text = "GLORY PROTECT"
	var primary_text: String = (
		"Продолжить"
		if _active_game != null and is_instance_valid(_active_game)
		else "Новая игра"
	)
	_add_button(primary_text, start_new_game)
	_add_button("Настройки", _open_settings_from_main)
	_add_button("Выйти из игры", _quit_game)
	_focus_first_button()


func _show_pause_menu() -> void:
	_screen = Screen.PAUSE
	_settings_return_screen = Screen.PAUSE
	_set_overlay_visible(true)
	_clear_body()
	_title_label.text = "ПАУЗА"
	_add_button("Продолжить", _resume_run)
	_add_button("Перезапустить забег", restart_active_run)
	_add_button("Настройки", _open_settings_from_pause)
	_add_button("Выйти из игры", _quit_game)
	_focus_first_button()


func _open_settings_from_main() -> void:
	_settings_return_screen = Screen.MAIN
	_show_audio_settings()


func _open_settings_from_pause() -> void:
	_settings_return_screen = Screen.PAUSE
	_show_audio_settings()


func _show_audio_settings() -> void:
	_screen = Screen.SETTINGS_AUDIO
	_waiting_action = &""
	_waiting_button = null
	_set_overlay_visible(true)
	_clear_body()
	_title_label.text = "НАСТРОЙКИ — АУДИО"
	_add_settings_tabs(true)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720.0, 430.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	_add_audio_slider(
		content,
		"Общая громкость эффектов",
		AppSettings.get_effects_volume(),
		_on_effects_volume_changed
	)
	_add_audio_slider(
		content,
		"Общая громкость саундтреков",
		AppSettings.get_music_volume(),
		_on_music_volume_changed
	)
	_add_separator(content, "Отдельные эффекты — тестовая настройка")
	for sound_id: StringName in AppSettings.get_sound_ids():
		_add_sound_slider(content, sound_id)
	_add_button("Сбросить громкость", _reset_audio)
	_add_button("Назад", _return_from_settings)
	_focus_first_button()


func _show_control_settings() -> void:
	_screen = Screen.SETTINGS_CONTROLS
	_waiting_action = &""
	_waiting_button = null
	_set_overlay_visible(true)
	_clear_body()
	_title_label.text = "НАСТРОЙКИ — УПРАВЛЕНИЕ"
	_add_settings_tabs(false)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720.0, 430.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)
	var previous_group: String = ""
	for spec: Dictionary in AppSettings.get_action_specs():
		var group_name: String = spec["group"]
		if group_name != previous_group:
			_add_separator(content, group_name)
			previous_group = group_name
		_add_binding_row(content, spec)
	_add_button("Сбросить управление", _reset_controls)
	_add_button("Назад", _return_from_settings)
	_focus_first_button()


func _add_settings_tabs(audio_selected: bool) -> void:
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 12)
	_body.add_child(tabs)
	var audio_button := _make_button("Аудио")
	audio_button.disabled = audio_selected
	audio_button.pressed.connect(_show_audio_settings)
	tabs.add_child(audio_button)
	var controls_button := _make_button("Управление")
	controls_button.disabled = not audio_selected
	controls_button.pressed.connect(_show_control_settings)
	tabs.add_child(controls_button)


func _add_audio_slider(
	parent: VBoxContainer,
	label_text: String,
	value: float,
	callback: Callable
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 310.0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = value * 100.0
	slider.custom_minimum_size.x = 260.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 58.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = "%d%%" % roundi(slider.value)
	row.add_child(value_label)
	slider.value_changed.connect(callback.bind(value_label))


func _add_sound_slider(parent: VBoxContainer, sound_id: StringName) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := Label.new()
	label.text = AppSettings.get_sound_label(sound_id)
	label.custom_minimum_size.x = 310.0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = AppSettings.get_sound_volume(sound_id) * 100.0
	slider.custom_minimum_size.x = 260.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 58.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = "%d%%" % roundi(slider.value)
	row.add_child(value_label)
	slider.value_changed.connect(
		_on_sound_volume_changed.bind(sound_id, value_label)
	)


func _add_binding_row(parent: VBoxContainer, spec: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := Label.new()
	label.text = spec["label"]
	label.custom_minimum_size.x = 440.0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var action_id: StringName = spec["id"]
	var button := _make_button(AppSettings.get_binding_text(action_id))
	button.custom_minimum_size.x = 190.0
	button.pressed.connect(_begin_rebind.bind(action_id, button))
	row.add_child(button)


func _add_separator(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	parent.add_child(label)
	var line := HSeparator.new()
	parent.add_child(line)


func _on_effects_volume_changed(value: float, value_label: Label) -> void:
	value_label.text = "%d%%" % roundi(value)
	AppSettings.set_effects_volume(value / 100.0)


func _on_music_volume_changed(value: float, value_label: Label) -> void:
	value_label.text = "%d%%" % roundi(value)
	AppSettings.set_music_volume(value / 100.0)


func _on_sound_volume_changed(
	value: float,
	sound_id: StringName,
	value_label: Label
) -> void:
	value_label.text = "%d%%" % roundi(value)
	AppSettings.set_sound_volume(sound_id, value / 100.0)


func _begin_rebind(action_id: StringName, button: Button) -> void:
	if _waiting_button != null and is_instance_valid(_waiting_button):
		_waiting_button.text = AppSettings.get_binding_text(_waiting_action)
	_waiting_action = action_id
	_waiting_button = button
	button.text = "Нажмите клавишу…"


func _handle_rebind_event(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	get_viewport().set_input_as_handled()
	if key_event.keycode == KEY_ESCAPE:
		_waiting_button.text = AppSettings.get_binding_text(_waiting_action)
		_waiting_action = &""
		_waiting_button = null
		return
	var keycode: Key = key_event.physical_keycode
	if keycode == KEY_NONE:
		keycode = key_event.keycode
	AppSettings.rebind_action(_waiting_action, keycode)
	_waiting_action = &""
	_waiting_button = null
	_show_control_settings()


func _reset_audio() -> void:
	AppSettings.reset_audio_defaults()
	_show_audio_settings()


func _reset_controls() -> void:
	AppSettings.reset_input_defaults()
	_show_control_settings()


func _return_from_settings() -> void:
	_waiting_action = &""
	_waiting_button = null
	if _settings_return_screen == Screen.PAUSE:
		_show_pause_menu()
	else:
		_show_main_menu()


func _on_restart_requested() -> void:
	restart_active_run()


func _on_run_state_changed(_previous_state: int, new_state: int) -> void:
	if new_state == GameFlowController.RunState.MANUAL_PAUSE:
		if _screen == Screen.NONE:
			_show_pause_menu()
	elif _screen == Screen.PAUSE:
		_screen = Screen.NONE
		_set_overlay_visible(false)


func _quit_game() -> void:
	get_tree().quit()


func _create_menu_ui() -> void:
	_menu_layer = CanvasLayer.new()
	_menu_layer.name = "MenuLayer"
	_menu_layer.layer = 100
	add_child(_menu_layer)
	_overlay = ColorRect.new()
	_overlay.name = "MenuOverlay"
	_overlay.color = Color(0.015, 0.025, 0.045, 0.92)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_layer.add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(760.0, 0.0)
	center.add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_panel.add_child(margin)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 14)
	margin.add_child(root_box)
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	root_box.add_child(_title_label)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	root_box.add_child(_body)


func _add_button(text: String, callback: Callable) -> Button:
	var button := _make_button(text)
	button.pressed.connect(callback)
	_body.add_child(button)
	return button


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260.0, 46.0)
	button.add_theme_font_size_override("font_size", 20)
	return button


func _focus_first_button() -> void:
	for child: Node in _body.get_children():
		if child is Button and not (child as Button).disabled:
			(child as Button).grab_focus()
			return
		if child is HBoxContainer:
			for nested: Node in child.get_children():
				if nested is Button and not (nested as Button).disabled:
					(nested as Button).grab_focus()
					return


func _clear_body() -> void:
	for child: Node in _body.get_children():
		child.queue_free()


func _set_overlay_visible(value: bool) -> void:
	_overlay.visible = value
