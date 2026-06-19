class_name CrewDebugInput
extends Node

signal selected_defender_changed(defender_id: int)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("CrewManager") var crew_manager_path: NodePath
@export_node_path("CrewRoleManager") var role_manager_path: NodePath

var selected_defender_id: int = 0

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _crew: CrewManager = get_node(crew_manager_path)
@onready var _roles: CrewRoleManager = get_node(role_manager_path)


func _unhandled_input(event: InputEvent) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_5:
			_select_defender(0)
		KEY_6:
			_select_defender(1)
		KEY_7:
			_select_defender(2)
		KEY_D:
			_roles.request_assignment(selected_defender_id, CrewRole.Id.DRIVER)
		KEY_Z:
			_roles.request_assignment(selected_defender_id, CrewRole.Id.LEFT_ANCHOR)
		KEY_X:
			_roles.request_assignment(selected_defender_id, CrewRole.Id.RIGHT_ANCHOR)
		KEY_C:
			_roles.request_assignment(selected_defender_id, CrewRole.Id.FREE_FIGHTER)
		_:
			return

	get_viewport().set_input_as_handled()


func _select_defender(defender_id: int) -> void:
	if _crew.get_defender(defender_id) == null:
		return
	selected_defender_id = defender_id
	selected_defender_changed.emit(selected_defender_id)
