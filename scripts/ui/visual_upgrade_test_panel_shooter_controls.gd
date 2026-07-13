class_name VisualUpgradeTestPanelShooterControls
extends VisualUpgradeTestPanelRunControls

const SHOOTER_UNLOCK_CARD_ID: StringName = &"shooter_unlock"

var _shooter_toggle: CheckButton


func configure(game: Node) -> void:
	super.configure(game)
	_build_shooter_toggle()
	_refresh_run_control_state()


func is_shooter_enabled_for_tests() -> bool:
	return is_upgrade_selected_for_tests(SHOOTER_UNLOCK_CARD_ID)


func set_shooter_enabled_for_tests(enabled: bool) -> bool:
	if is_shooter_enabled_for_tests() == enabled:
		_sync_shooter_toggle()
		return true
	var changed: bool = toggle_upgrade_for_tests(
		SHOOTER_UNLOCK_CARD_ID,
		enabled
	)
	_sync_shooter_toggle()
	_refresh_run_control_state()
	if changed:
		_set_run_feedback(
			"Стрелок включён" if enabled else "Стрелок отключён"
		)
	else:
		_set_run_feedback("Не удалось изменить доступность стрелка")
	return changed and is_shooter_enabled_for_tests() == enabled


func _build_shooter_toggle() -> void:
	var panel: PanelContainer = get_node_or_null(
		"VisualRunControlsRoot/RunControlsPanel"
	) as PanelContainer
	if panel == null:
		return
	panel.offset_bottom = 330.0
	var box: VBoxContainer = panel.get_node_or_null(
		"MarginContainer/VBoxContainer"
	) as VBoxContainer
	if box == null:
		return
	_shooter_toggle = CheckButton.new()
	_shooter_toggle.name = "ShooterToggle"
	_shooter_toggle.text = "Стрелок"
	_shooter_toggle.toggled.connect(_on_shooter_toggled)
	box.add_child(_shooter_toggle)
	if _run_feedback != null and _run_feedback.get_parent() == box:
		box.move_child(_shooter_toggle, _run_feedback.get_index())
	_sync_shooter_toggle()


func _refresh_run_control_state() -> void:
	super._refresh_run_control_state()
	if _run_counts != null:
		_run_counts.text += " · стрелок: %s" % (
			"вкл" if is_shooter_enabled_for_tests() else "выкл"
		)
	_sync_shooter_toggle()


func _sync_shooter_toggle() -> void:
	if _shooter_toggle == null:
		return
	var enabled: bool = is_shooter_enabled_for_tests()
	_shooter_toggle.set_pressed_no_signal(enabled)
	_shooter_toggle.text = "Стрелок: %s" % (
		"ВКЛ" if enabled else "ВЫКЛ"
	)


func _on_shooter_toggled(enabled: bool) -> void:
	set_shooter_enabled_for_tests(enabled)
