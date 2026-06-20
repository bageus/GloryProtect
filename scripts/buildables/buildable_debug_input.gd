class_name BuildableDebugInput
extends Node

signal selected_cell_changed(cell_index: int)
signal command_feedback(message: StringName)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("BuildableInventory") var inventory_path: NodePath
@export_node_path("BuildableGrid") var grid_path: NodePath
@export_node_path("CrewRoleManager") var role_manager_path: NodePath
@export_node_path("CrewDebugInput") var crew_debug_input_path: NodePath
@export var balance: BuildableBalance

var selected_cell_index: int = 0

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _platform: PlatformController = get_node(platform_path)
@onready var _inventory: BuildableInventory = get_node(inventory_path)
@onready var _grid: BuildableGrid = get_node(grid_path)
@onready var _roles: CrewRoleManager = get_node(role_manager_path)
@onready var _crew_input: CrewDebugInput = get_node(crew_debug_input_path)


func _ready() -> void:
	assert(balance != null, "BuildableDebugInput requires BuildableBalance")
	selected_cell_index = clampi(
		balance.default_medical_cell,
		0,
		_platform.get_cell_count() - 1
	)
	selected_cell_changed.emit(selected_cell_index)


func _unhandled_input(event: InputEvent) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_COMMA:
			_select_cell(selected_cell_index - 1)
		KEY_PERIOD:
			_select_cell(selected_cell_index + 1)
		KEY_B:
			_unlock_medical_station()
		KEY_M:
			_place_or_move_medical_station()
		KEY_DELETE:
			_demolish_medical_station()
		KEY_H:
			_roles.request_assignment(
				_crew_input.selected_defender_id,
				CrewRole.Id.MEDIC
			)
		_:
			return
	get_viewport().set_input_as_handled()


func get_selected_cell_index() -> int:
	return selected_cell_index


func get_summary() -> String:
	return "выбрана клетка %d" % (selected_cell_index + 1)


func _select_cell(cell_index: int) -> void:
	selected_cell_index = wrapi(cell_index, 0, _platform.get_cell_count())
	selected_cell_changed.emit(selected_cell_index)


func _unlock_medical_station() -> void:
	var count: int = _inventory.unlock(BuildableType.Id.MEDICAL_STATION)
	if count > 0:
		command_feedback.emit(&"medical_station_unlocked")
	else:
		command_feedback.emit(&"medical_station_unlock_failed")


func _place_or_move_medical_station() -> void:
	if not _inventory.is_unlocked(BuildableType.Id.MEDICAL_STATION):
		command_feedback.emit(&"medical_station_locked")
		return
	var medical_id: int = _grid.get_buildable_id_by_type(
		BuildableType.Id.MEDICAL_STATION
	)
	if medical_id < 0:
		medical_id = _grid.place(
			BuildableType.Id.MEDICAL_STATION,
			selected_cell_index
		)
		command_feedback.emit(
			&"medical_station_placed" if medical_id >= 0
			else &"medical_station_place_failed"
		)
		return
	var moved: bool = _grid.move(medical_id, selected_cell_index)
	command_feedback.emit(
		&"medical_station_moved" if moved
		else &"medical_station_move_failed"
	)


func _demolish_medical_station() -> void:
	var medical_id: int = _grid.get_buildable_id_by_type(
		BuildableType.Id.MEDICAL_STATION
	)
	if medical_id < 0:
		command_feedback.emit(&"medical_station_missing")
		return
	command_feedback.emit(
		&"medical_station_demolished" if _grid.demolish(medical_id)
		else &"medical_station_demolish_failed"
	)
