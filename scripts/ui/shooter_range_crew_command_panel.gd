class_name ShooterRangeCrewCommandPanel
extends CrewCommandPanelPlacementPolished

var _range_context_defender_id: int = -1


func _process(delta: float) -> void:
	super._process(delta)
	if not visible and _range_context_defender_id >= 0:
		_close_context()


func open_defender_command_context(defender_id: int) -> void:
	_hide_defender_attack_range()
	var defender: Defender = _crew.get_defender(defender_id)
	if defender == null or not defender.health.is_alive():
		_close_context()
		return
	if not _selection.select_defender(defender_id):
		_close_context()
		return
	_range_context_defender_id = defender_id
	_set_defender_attack_range_visible(defender_id, true)
	super.open_defender_command_context(defender_id)


func close_defender_command_context() -> void:
	_close_context()


func _close_context() -> void:
	_hide_defender_attack_range()
	super._close_context()


func _on_slot_pressed(slot_index: int) -> void:
	_hide_defender_attack_range()
	super._on_slot_pressed(slot_index)


func _on_defender_died(defender_id: int) -> void:
	if defender_id == _range_context_defender_id:
		_close_context()
	super._on_defender_died(defender_id)


func _set_defender_attack_range_visible(
	defender_id: int,
	visible_value: bool
) -> void:
	var defender: Defender = _crew.get_defender(defender_id)
	if defender == null:
		return
	var visual := defender.visual as ShooterRangeDefenderVisual
	if visual != null:
		visual.set_attack_range_context_visible(visible_value)


func _hide_defender_attack_range() -> void:
	if _range_context_defender_id >= 0:
		_set_defender_attack_range_visible(
			_range_context_defender_id,
			false
		)
	_range_context_defender_id = -1
