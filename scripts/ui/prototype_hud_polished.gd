class_name PrototypeHUDPolished
extends PrototypeHUD

var _crew_command_panel: ShooterRangeCrewCommandPanel


func _create_crew_command_panel() -> void:
	_crew_command_panel = ShooterRangeCrewCommandPanel.new()
	_crew_command_panel.name = "CrewCommandPanel"
	_crew_command_panel.configure(
		_game_flow,
		_crew_input,
		_crew_roles,
		_replacements,
		_buildable_grid
	)
	add_child(_crew_command_panel)
	if not _crew_input.defender_world_clicked.is_connected(
		_crew_command_panel.open_defender_command_context
	):
		_crew_input.defender_world_clicked.connect(
			_crew_command_panel.open_defender_command_context
		)
	if _placement != null:
		if not _placement.selected_cell_changed.is_connected(
			_on_selected_cell_changed
		):
			_placement.selected_cell_changed.connect(
				_on_selected_cell_changed
			)
		if not _placement.selected_buildable_changed.is_connected(
			_on_selected_buildable_changed
		):
			_placement.selected_buildable_changed.connect(
				_on_selected_buildable_changed
			)


func _on_selected_cell_changed(cell_index: int) -> void:
	if cell_index >= 0:
		_crew_command_panel.close_defender_command_context()


func _on_selected_buildable_changed(buildable_id: int) -> void:
	if buildable_id >= 0:
		_crew_command_panel.close_defender_command_context()
