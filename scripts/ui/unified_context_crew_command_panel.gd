class_name UnifiedContextCrewCommandPanel
extends ShooterRangeCrewCommandPanel


enum ContextKind {
	NONE,
	CREW,
	BUILDABLE,
}

var _placement: BuildablePlacementController
var _context_kind: int = ContextKind.NONE
var _suppress_placement_refresh: bool = false


func set_placement_controller(controller: BuildablePlacementController) -> void:
	_placement = controller
	_connect_placement_signals()


func _ready() -> void:
	super._ready()
	_connect_placement_signals()
	_refresh_buildable_context_if_active()


func _process(delta: float) -> void:
	super._process(delta)
	if _context_kind != ContextKind.BUILDABLE:
		return
	if not visible:
		_close_context()
		return
	_rebuild_buildable_context()


func is_context_visible() -> bool:
	return _view.is_context_visible()


func get_context_button_texts() -> PackedStringArray:
	return _view.get_context_button_texts()


func open_defender_command_context(defender_id: int) -> void:
	_clear_placement_selection_without_refresh()
	_context_kind = ContextKind.CREW
	super.open_defender_command_context(defender_id)


func _on_slot_pressed(slot_index: int) -> void:
	_clear_placement_selection_without_refresh()
	_context_kind = ContextKind.CREW
	super._on_slot_pressed(slot_index)


func _close_context() -> void:
	var clear_buildable_context: bool = _context_kind == ContextKind.BUILDABLE
	_context_kind = ContextKind.NONE
	if clear_buildable_context:
		_clear_placement_selection_without_refresh()
	super._close_context()


func _on_buildable_unlocked(type_id: int, count: int) -> void:
	super._on_buildable_unlocked(type_id, count)
	if _context_kind == ContextKind.BUILDABLE:
		_rebuild_buildable_context()


func _on_buildable_changed(
	_buildable_id: int,
	_type_id: int,
	_cell_index: int
) -> void:
	_update_slots()
	if _context_kind == ContextKind.BUILDABLE:
		_rebuild_buildable_context()
	elif _view.is_context_visible():
		_rebuild_context_menu()


func _on_buildable_moved(
	_buildable_id: int,
	_previous_cell: int,
	_cell_index: int
) -> void:
	_update_slots()
	if _context_kind == ContextKind.BUILDABLE:
		_rebuild_buildable_context()


func _on_assignment_changed(
	_defender_id: int,
	_current_role: int,
	_target_role: int,
	_state: int
) -> void:
	_update_slots()
	if _context_kind == ContextKind.BUILDABLE:
		_rebuild_buildable_context()
	elif _view.is_context_visible():
		_rebuild_context_menu()


func _connect_placement_signals() -> void:
	if _placement == null:
		return
	if not _placement.mode_changed.is_connected(_on_placement_mode_changed):
		_placement.mode_changed.connect(_on_placement_mode_changed)
	if not _placement.selected_cell_changed.is_connected(
		_on_placement_cell_changed
	):
		_placement.selected_cell_changed.connect(_on_placement_cell_changed)
	if not _placement.selected_buildable_changed.is_connected(
		_on_placement_buildable_changed
	):
		_placement.selected_buildable_changed.connect(
			_on_placement_buildable_changed
		)
	if not _placement.feedback_changed.is_connected(_on_placement_feedback_changed):
		_placement.feedback_changed.connect(_on_placement_feedback_changed)


func _on_placement_mode_changed(
	_mode: int,
	_type_id: int,
	_buildable_id: int
) -> void:
	_refresh_buildable_context_if_active()


func _on_placement_cell_changed(_cell_index: int) -> void:
	_refresh_buildable_context_if_active()


func _on_placement_buildable_changed(_buildable_id: int) -> void:
	_refresh_buildable_context_if_active()


func _on_placement_feedback_changed(_message: String, _is_error: bool) -> void:
	if _context_kind == ContextKind.BUILDABLE:
		_rebuild_buildable_context()


func _refresh_buildable_context_if_active() -> void:
	if _suppress_placement_refresh or _placement == null:
		return
	if _placement.has_cell_context() or _placement.get_mode() != BuildablePlacementController.Mode.IDLE:
		_context_kind = ContextKind.BUILDABLE
		_selected_slot = -1
		_hide_defender_attack_range()
		_rebuild_buildable_context()
	elif _context_kind == ContextKind.BUILDABLE:
		_context_kind = ContextKind.NONE
		super._close_context()


func _rebuild_buildable_context() -> void:
	if _placement == null or _suppress_placement_refresh:
		return
	var cell_index: int = _get_buildable_context_cell_index()
	_view.rebuild_buildable_context(
		_get_buildable_context_title(cell_index),
		_get_buildable_context_status(cell_index),
		_build_buildable_actions(cell_index),
		_get_buildable_feedback_text(),
		_placement.is_feedback_error(),
		_close_context
	)


func _build_buildable_actions(cell_index: int) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if _placement.get_mode() != BuildablePlacementController.Mode.IDLE:
		actions.append(_make_buildable_action("Отмена", _on_buildable_cancel_pressed))
		return actions

	var selected_id: int = _placement.get_selected_buildable_id()
	var snapshot: BuildableSnapshot = _grid.get_snapshot(selected_id)
	if snapshot != null:
		if snapshot.type_id != BuildableType.Id.MEDICAL_STATION:
			actions.append(
				_make_buildable_action(
					"Перенести",
					_on_buildable_move_pressed,
					not _placement.are_commands_enabled()
				)
			)
		actions.append(
			_make_buildable_action(
				"Демонтировать",
				_on_buildable_demolish_pressed,
				not _placement.are_commands_enabled()
			)
		)
		return actions

	if cell_index < 0:
		return actions
	if _can_place_buildable_type(BuildableType.Id.MEDICAL_STATION):
		actions.append(
			_make_buildable_action(
				_get_deploy_button_text(BuildableType.Id.MEDICAL_STATION),
				_on_buildable_medical_pressed
			)
		)
	if _can_place_buildable_type(BuildableType.Id.TURRET):
		actions.append(
			_make_buildable_action(
				_get_deploy_button_text(BuildableType.Id.TURRET),
				_on_buildable_turret_pressed
			)
		)
	return actions


func _make_buildable_action(
	text: String,
	callback: Callable,
	disabled: bool = false
) -> Dictionary:
	return {
		"text": text,
		"callback": callback,
		"disabled": disabled,
	}


func _can_place_buildable_type(type_id: int) -> bool:
	return (
		_placement.are_commands_enabled()
		and _placement.get_mode() == BuildablePlacementController.Mode.IDLE
		and _placement.get_selected_buildable_id() < 0
		and _placement.get_selected_cell_index() >= 0
		and _placement.can_place_type_in_selected_cell(type_id)
	)


func _get_deploy_button_text(type_id: int) -> String:
	var deployed: int = _grid.get_count_by_type(type_id)
	var unlocked: int = _inventory.get_unlocked_count(type_id)
	return "%s %d/%d" % [_get_buildable_type_title(type_id), deployed, unlocked]


func _get_buildable_context_cell_index() -> int:
	if _placement.get_mode() != BuildablePlacementController.Mode.IDLE:
		var hovered_cell: int = _placement.get_hovered_cell_index()
		if hovered_cell >= 0:
			return hovered_cell
	return _placement.get_selected_cell_index()


func _get_buildable_context_title(cell_index: int) -> String:
	if cell_index < 0:
		return "Контекст платформы"
	return "Ячейка %d" % (cell_index + 1)


func _get_buildable_context_status(cell_index: int) -> String:
	if _placement.get_mode() == BuildablePlacementController.Mode.PLACE:
		return "Установка объекта"
	if _placement.get_mode() == BuildablePlacementController.Mode.MOVE:
		return "Перенос объекта"
	if cell_index < 0:
		return "Клетка не выбрана"
	var selected_id: int = _placement.get_selected_buildable_id()
	var snapshot: BuildableSnapshot = _grid.get_snapshot(selected_id)
	if snapshot == null:
		var occupant_id: int = _grid.get_buildable_id_at_cell(cell_index)
		snapshot = _grid.get_snapshot(occupant_id)
	if snapshot == null:
		return "Пустая"
	return _get_buildable_type_title(snapshot.type_id)


func _get_buildable_feedback_text() -> String:
	var message: String = _placement.get_feedback_message()
	if message.begins_with("Выберите объект для клетки"):
		return ""
	return message


func _get_buildable_type_title(type_id: int) -> String:
	if type_id == BuildableType.Id.MEDICAL_STATION:
		return "Медпост"
	if type_id == BuildableType.Id.TURRET:
		return "Турель"
	return BuildableType.get_display_name(type_id)


func _on_buildable_medical_pressed() -> void:
	if _placement == null:
		return
	if not _placement.place_type_in_selected_cell(BuildableType.Id.MEDICAL_STATION):
		_placement.begin_placement(BuildableType.Id.MEDICAL_STATION)
	_refresh_buildable_context_if_active()


func _on_buildable_turret_pressed() -> void:
	if _placement == null:
		return
	if not _placement.place_type_in_selected_cell(BuildableType.Id.TURRET):
		_placement.begin_placement(BuildableType.Id.TURRET)
	_refresh_buildable_context_if_active()


func _on_buildable_move_pressed() -> void:
	if _placement != null:
		_placement.begin_move_selected()
		_refresh_buildable_context_if_active()


func _on_buildable_demolish_pressed() -> void:
	if _placement != null:
		_placement.demolish_selected()
		_refresh_buildable_context_if_active()


func _on_buildable_cancel_pressed() -> void:
	if _placement != null:
		_placement.cancel_current_action()
	_refresh_buildable_context_if_active()


func _clear_placement_selection_without_refresh() -> void:
	if _placement == null:
		return
	if (
		not _placement.has_cell_context()
		and _placement.get_mode() == BuildablePlacementController.Mode.IDLE
	):
		return
	_suppress_placement_refresh = true
	_placement.clear_selection()
	_suppress_placement_refresh = false
