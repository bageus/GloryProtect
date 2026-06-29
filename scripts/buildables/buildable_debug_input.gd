class_name BuildableDebugInput
extends Node

signal selected_cell_changed(cell_index: int)
signal command_feedback(message: StringName)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("BuildableInventory") var inventory_path: NodePath
@export_node_path("BuildableGrid") var grid_path: NodePath
@export_node_path("CrewRoleManager") var role_manager_path: NodePath
@export_node_path("CrewSelectionController") var crew_debug_input_path: NodePath
@export var balance: BuildableBalance

var selected_cell_index: int = 0

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _platform: PlatformController = get_node(platform_path)
@onready var _inventory: BuildableInventory = get_node(inventory_path)
@onready var _grid: BuildableGrid = get_node(grid_path)
@onready var _roles: CrewRoleManager = get_node(role_manager_path)
@onready var _crew_selection: CrewSelectionController = get_node(crew_debug_input_path)


func _ready() -> void:
	assert(balance != null, "BuildableDebugInput requires BuildableBalance")
	selected_cell_index = clampi(
		_get_medical_anchor_cell(),
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
	if key_event.is_action_pressed(&"gp_cell_previous"):
		_select_cell(selected_cell_index - 1)
	elif key_event.is_action_pressed(&"gp_cell_next"):
		_select_cell(selected_cell_index + 1)
	elif key_event.is_action_pressed(&"gp_unlock_medical"):
		_unlock_medical_station()
	elif key_event.is_action_pressed(&"gp_place_medical"):
		_ensure_medical_station()
	elif key_event.is_action_pressed(&"gp_demolish_medical"):
		_demolish_medical_station()
	elif key_event.is_action_pressed(&"gp_assign_medic"):
		_roles.request_assignment(
			_crew_selection.get_selected_defender_id(),
			CrewRole.Id.MEDIC
		)
	else:
		return
	get_viewport().set_input_as_handled()


func get_selected_cell_index() -> int:
	return selected_cell_index


func select_cell(cell_index: int) -> void:
	_select_cell(cell_index)


func get_summary() -> String:
	return "выбрана клетка %d" % (selected_cell_index + 1)


func _select_cell(cell_index: int) -> void:
	selected_cell_index = wrapi(cell_index, 0, _platform.get_cell_count())
	selected_cell_changed.emit(selected_cell_index)


func _unlock_medical_station() -> void:
	var before: int = _inventory.get_unlocked_count(
		BuildableType.Id.MEDICAL_STATION
	)
	var after: int = _inventory.unlock(BuildableType.Id.MEDICAL_STATION)
	if after > before:
		command_feedback.emit(&"medical_station_unlocked")
	else:
		command_feedback.emit(&"medical_station_unlock_failed")


func _ensure_medical_station() -> void:
	if not _inventory.is_unlocked(BuildableType.Id.MEDICAL_STATION):
		_inventory.unlock(BuildableType.Id.MEDICAL_STATION)
	if _grid.get_buildable_id_by_type(BuildableType.Id.MEDICAL_STATION) >= 0:
		command_feedback.emit(&"medical_station_already_placed")
		return
	var anchor_cell: int = _get_medical_anchor_cell()
	_select_cell(anchor_cell)
	var medical_id: int = _grid.place(
		BuildableType.Id.MEDICAL_STATION,
		anchor_cell
	)
	if medical_id >= 0:
		command_feedback.emit(&"medical_station_placed")
	else:
		command_feedback.emit(&"medical_station_place_failed")


func _demolish_medical_station() -> void:
	var medical_id: int = _grid.get_buildable_id_by_type(
		BuildableType.Id.MEDICAL_STATION
	)
	if medical_id < 0:
		command_feedback.emit(&"medical_station_missing")
		return
	if _grid.demolish(medical_id):
		command_feedback.emit(&"medical_station_demolished")
	else:
		command_feedback.emit(&"medical_station_demolish_failed")


func _get_medical_anchor_cell() -> int:
	var cells: Array[int] = balance.get_medical_cell_indices()
	return 0 if cells.is_empty() else cells[0]
