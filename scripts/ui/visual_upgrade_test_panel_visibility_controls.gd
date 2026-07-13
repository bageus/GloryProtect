class_name VisualUpgradeTestPanelVisibilityControls
extends VisualUpgradeTestPanelShooterControls

const MENU_TOGGLE_TOP := 16.0
const MENU_TOGGLE_BOTTOM := 50.0
const MENU_PANEL_TOP := 58.0

var _run_menu_panel: PanelContainer
var _upgrade_menu_panel: PanelContainer
var _run_menu_toggle: Button
var _upgrade_menu_toggle: Button


func configure(game: Node) -> void:
	super.configure(game)
	_bind_test_menu_panels()
	_build_menu_visibility_controls()
	_sync_menu_visibility_controls()


func is_run_menu_visible_for_tests() -> bool:
	return _run_menu_panel != null and _run_menu_panel.visible


func is_upgrade_menu_visible_for_tests() -> bool:
	return _upgrade_menu_panel != null and _upgrade_menu_panel.visible


func set_run_menu_visible_for_tests(visible: bool) -> void:
	_set_run_menu_visible(visible)


func set_upgrade_menu_visible_for_tests(visible: bool) -> void:
	_set_upgrade_menu_visible(visible)


func get_run_menu_toggle_text_for_tests() -> String:
	return "" if _run_menu_toggle == null else _run_menu_toggle.text


func get_upgrade_menu_toggle_text_for_tests() -> String:
	return "" if _upgrade_menu_toggle == null else _upgrade_menu_toggle.text


func _bind_test_menu_panels() -> void:
	_run_menu_panel = get_node_or_null(
		"VisualRunControlsRoot/RunControlsPanel"
	) as PanelContainer
	_upgrade_menu_panel = get_node_or_null(
		"VisualUpgradeTestRoot/UpgradeTreePanel"
	) as PanelContainer
	if _run_menu_panel != null:
		var panel_height: float = (
			_run_menu_panel.offset_bottom - _run_menu_panel.offset_top
		)
		_run_menu_panel.offset_top = MENU_PANEL_TOP
		_run_menu_panel.offset_bottom = MENU_PANEL_TOP + panel_height
	if _upgrade_menu_panel != null:
		_upgrade_menu_panel.offset_top = MENU_PANEL_TOP


func _build_menu_visibility_controls() -> void:
	var run_root: Control = get_node_or_null(
		"VisualRunControlsRoot"
	) as Control
	if run_root != null:
		_run_menu_toggle = Button.new()
		_run_menu_toggle.name = "RunMenuVisibilityToggle"
		_run_menu_toggle.offset_left = 12.0
		_run_menu_toggle.offset_right = 230.0
		_run_menu_toggle.offset_top = MENU_TOGGLE_TOP
		_run_menu_toggle.offset_bottom = MENU_TOGGLE_BOTTOM
		_run_menu_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
		_run_menu_toggle.pressed.connect(_on_run_menu_toggle_pressed)
		run_root.add_child(_run_menu_toggle)

	var upgrade_root: Control = get_node_or_null(
		"VisualUpgradeTestRoot"
	) as Control
	if upgrade_root != null:
		_upgrade_menu_toggle = Button.new()
		_upgrade_menu_toggle.name = "UpgradeMenuVisibilityToggle"
		_upgrade_menu_toggle.anchor_left = 1.0
		_upgrade_menu_toggle.anchor_right = 1.0
		_upgrade_menu_toggle.offset_left = -230.0
		_upgrade_menu_toggle.offset_right = -8.0
		_upgrade_menu_toggle.offset_top = MENU_TOGGLE_TOP
		_upgrade_menu_toggle.offset_bottom = MENU_TOGGLE_BOTTOM
		_upgrade_menu_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
		_upgrade_menu_toggle.pressed.connect(_on_upgrade_menu_toggle_pressed)
		upgrade_root.add_child(_upgrade_menu_toggle)


func _set_run_menu_visible(visible: bool) -> void:
	if _run_menu_panel != null:
		_run_menu_panel.visible = visible
	_sync_menu_visibility_controls()


func _set_upgrade_menu_visible(visible: bool) -> void:
	if _upgrade_menu_panel != null:
		_upgrade_menu_panel.visible = visible
	_sync_menu_visibility_controls()


func _sync_menu_visibility_controls() -> void:
	if _run_menu_toggle != null:
		_run_menu_toggle.text = (
			"Скрыть тест забега"
			if is_run_menu_visible_for_tests()
			else "Открыть тест забега"
		)
	if _upgrade_menu_toggle != null:
		_upgrade_menu_toggle.text = (
			"Скрыть тест улучшений"
			if is_upgrade_menu_visible_for_tests()
			else "Открыть тест улучшений"
		)


func _on_run_menu_toggle_pressed() -> void:
	_set_run_menu_visible(not is_run_menu_visible_for_tests())


func _on_upgrade_menu_toggle_pressed() -> void:
	_set_upgrade_menu_visible(not is_upgrade_menu_visible_for_tests())
