class_name PrototypeHUDPolished
extends PrototypeHUD

var _crew_command_panel: UnifiedContextCrewCommandPanel


func _create_crew_command_panel() -> void:
	_crew_command_panel = UnifiedContextCrewCommandPanel.new()
	_crew_command_panel.name = "CrewCommandPanel"
	_crew_command_panel.configure(
		_game_flow,
		_crew_input,
		_crew_roles,
		_replacements,
		_buildable_grid
	)
	_crew_command_panel.set_placement_controller(_placement)
	add_child(_crew_command_panel)
	if not _crew_input.defender_world_clicked.is_connected(
		_crew_command_panel.open_defender_command_context
	):
		_crew_input.defender_world_clicked.connect(
			_crew_command_panel.open_defender_command_context
		)
