class_name PrototypeHUDPolished
extends PrototypeHUD


func _create_crew_command_panel() -> void:
	var panel := CrewCommandPanelPlacementPolished.new()
	panel.name = "CrewCommandPanel"
	panel.configure(
		_game_flow,
		_crew_input,
		_crew_roles,
		_replacements,
		_buildable_grid
	)
	add_child(panel)
