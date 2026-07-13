class_name VisualUpgradeTestPanelRunControls
extends VisualUpgradeTestPanel

var _crew_manager: CrewManager
var _buildable_inventory: BuildableInventory
var _buildable_grid: BuildableGrid
var _run_counts: Label
var _run_feedback: Label


func configure(game: Node) -> void:
	super.configure(game)
	_crew_manager = game.get_node("World/Platform/CrewManager") as CrewManager
	_buildable_inventory = game.get_node("BuildableInventory") as BuildableInventory
	_buildable_grid = game.get_node("World/BuildableGrid") as BuildableGrid
	_build_run_control_ui()
	_connect_run_control_signals()
	_refresh_run_control_state()


func get_defender_count_for_tests() -> int:
	return 0 if _crew_manager == null else _crew_manager.get_total_count()


func get_turret_count_for_tests() -> int:
	if _buildable_grid == null:
		return 0
	return _buildable_grid.get_count_by_type(BuildableType.Id.TURRET)


func is_medical_post_installed_for_tests() -> bool:
	return (
		_buildable_grid != null
		and _buildable_grid.get_buildable_id_by_type(
			BuildableType.Id.MEDICAL_STATION
		) >= 0
	)


func add_defender_for_tests() -> bool:
	return _add_defender()


func remove_defender_for_tests() -> bool:
	return _remove_defender()


func add_turret_for_tests() -> bool:
	return _add_turret()


func remove_turret_for_tests() -> bool:
	return _remove_turret()


func install_medical_post_for_tests() -> bool:
	return _install_medical_post()


func get_run_control_feedback_for_tests() -> String:
	return "" if _run_feedback == null else _run_feedback.text


func _build_run_control_ui() -> void:
	var root := Control.new()
	root.name = "VisualRunControlsRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.name = "RunControlsPanel"
	panel.offset_left = 12.0
	panel.offset_right = 320.0
	panel.offset_top = 16.0
	panel.offset_bottom = 286.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	var title := Label.new()
	title.text = "ТЕСТ ЗАБЕГА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	box.add_child(title)

	_run_counts = Label.new()
	_run_counts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_run_counts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_run_counts)

	box.add_child(_create_button_row(
		"Защитники",
		"−",
		Callable(self, "_on_remove_defender_pressed"),
		"+",
		Callable(self, "_on_add_defender_pressed")
	))
	box.add_child(_create_button_row(
		"Турели",
		"−",
		Callable(self, "_on_remove_turret_pressed"),
		"+",
		Callable(self, "_on_add_turret_pressed")
	))

	var medical_button := Button.new()
	medical_button.text = "Установить пост лекаря"
	medical_button.pressed.connect(_on_install_medical_pressed)
	box.add_child(medical_button)

	_run_feedback = Label.new()
	_run_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_run_feedback.add_theme_font_size_override("font_size", 12)
	box.add_child(_run_feedback)


func _create_button_row(
	caption: String,
	left_text: String,
	left_action: Callable,
	right_text: String,
	right_action: Callable
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var left := Button.new()
	left.text = left_text
	left.custom_minimum_size = Vector2(54.0, 34.0)
	left.pressed.connect(left_action)
	row.add_child(left)

	var right := Button.new()
	right.text = right_text
	right.custom_minimum_size = Vector2(54.0, 34.0)
	right.pressed.connect(right_action)
	row.add_child(right)
	return row


func _connect_run_control_signals() -> void:
	if _crew_manager != null:
		_crew_manager.crew_size_changed.connect(_on_run_state_changed)
	if _buildable_grid != null:
		_buildable_grid.buildable_placed.connect(_on_buildable_changed)
		_buildable_grid.buildable_demolished.connect(_on_buildable_changed)
		_buildable_grid.grid_reset.connect(_refresh_run_control_state)


func _add_defender() -> bool:
	if _crew_manager == null or _crew_manager.add_defender() == null:
		_set_run_feedback("Защитников уже максимум: 8")
		return false
	_set_run_feedback("Защитник добавлен")
	_refresh_run_control_state()
	return true


func _remove_defender() -> bool:
	if _crew_manager == null or not _crew_manager.remove_last_defender():
		_set_run_feedback("Нельзя оставить меньше 3 защитников")
		return false
	_set_run_feedback("Последний дополнительный защитник убран")
	_refresh_run_control_state()
	return true


func _add_turret() -> bool:
	if _buildable_inventory == null or _buildable_grid == null:
		return false
	var type_id: int = BuildableType.Id.TURRET
	var deployed_count: int = _buildable_grid.get_count_by_type(type_id)
	if not _buildable_inventory.can_deploy(type_id, deployed_count):
		_buildable_inventory.unlock(type_id)
	if not _buildable_inventory.can_deploy(type_id, deployed_count):
		_set_run_feedback("Достигнут лимит турелей")
		return false
	var preferred_cell: int = _buildable_grid.balance.default_medical_cell
	var cell_index: int = _buildable_grid.find_nearest_available_cell_for_type(
		type_id,
		preferred_cell
	)
	if cell_index < 0 or _buildable_grid.place(type_id, cell_index) < 0:
		_set_run_feedback("Нет свободной клетки для турели")
		return false
	_set_run_feedback("Турель установлена")
	_refresh_run_control_state()
	return true


func _remove_turret() -> bool:
	if _buildable_grid == null:
		return false
	var ids: Array[int] = _buildable_grid.get_buildable_ids_by_type(
		BuildableType.Id.TURRET
	)
	if ids.is_empty() or not _buildable_grid.demolish(ids[ids.size() - 1]):
		_set_run_feedback("Нет турели для удаления")
		return false
	_set_run_feedback("Последняя турель убрана")
	_refresh_run_control_state()
	return true


func _install_medical_post() -> bool:
	if _buildable_inventory == null or _buildable_grid == null:
		return false
	var type_id: int = BuildableType.Id.MEDICAL_STATION
	if _buildable_grid.get_buildable_id_by_type(type_id) >= 0:
		_set_run_feedback("Пост лекаря уже установлен")
		return false
	if not _buildable_inventory.is_unlocked(type_id):
		_buildable_inventory.unlock(type_id)
	var cell_index: int = _buildable_grid.find_nearest_available_cell_for_type(
		type_id,
		_buildable_grid.balance.default_medical_cell
	)
	if cell_index < 0 or _buildable_grid.place(type_id, cell_index) < 0:
		_set_run_feedback("Нет свободной клетки для поста лекаря")
		return false
	_set_run_feedback("Пост лекаря установлен")
	_refresh_run_control_state()
	return true


func _refresh_run_control_state() -> void:
	if _run_counts == null:
		return
	var defenders: int = get_defender_count_for_tests()
	var turrets: int = get_turret_count_for_tests()
	var medical: String = "есть" if is_medical_post_installed_for_tests() else "нет"
	_run_counts.text = "Защитники %d/8 (мин. 3) · турели %d/4 · пост: %s" % [
		defenders,
		turrets,
		medical,
	]


func _set_run_feedback(message: String) -> void:
	if _run_feedback != null:
		_run_feedback.text = message


func _on_add_defender_pressed() -> void:
	_add_defender()


func _on_remove_defender_pressed() -> void:
	_remove_defender()


func _on_add_turret_pressed() -> void:
	_add_turret()


func _on_remove_turret_pressed() -> void:
	_remove_turret()


func _on_install_medical_pressed() -> void:
	_install_medical_post()


func _on_run_state_changed(_previous_size: int, _current_size: int) -> void:
	_refresh_run_control_state()


func _on_buildable_changed(
	_buildable_id: int,
	_type_id: int,
	_cell_index: int
) -> void:
	_refresh_run_control_state()
