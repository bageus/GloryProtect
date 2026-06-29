class_name TurretDebugInput
extends Node

signal selected_turret_changed(buildable_id: int)
signal command_feedback(message: StringName)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("BuildableInventory") var inventory_path: NodePath
@export_node_path("BuildableGrid") var grid_path: NodePath
@export_node_path("BuildableDebugInput") var buildable_input_path: NodePath
@export_node_path("CrewRoleManager") var role_manager_path: NodePath
@export_node_path("CrewSelectionController") var crew_debug_input_path: NodePath

var selected_turret_id: int = -1

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _inventory: BuildableInventory = get_node(inventory_path)
@onready var _grid: BuildableGrid = get_node(grid_path)
@onready var _buildable_input: BuildableDebugInput = get_node(
	buildable_input_path
)
@onready var _roles: CrewRoleManager = get_node(role_manager_path)
@onready var _crew_selection: CrewSelectionController = get_node(
	crew_debug_input_path
)


func _ready() -> void:
	_grid.buildable_placed.connect(_on_buildable_placed)
	_grid.buildable_demolished.connect(_on_buildable_demolished)
	_grid.grid_reset.connect(_on_grid_reset)
	_select_first_available()


func _unhandled_input(event: InputEvent) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.is_action_pressed(&"gp_unlock_turret"):
		_unlock_turret()
	elif key_event.is_action_pressed(&"gp_place_turret"):
		_place_new_turret()
	elif key_event.is_action_pressed(&"gp_cycle_turret"):
		_cycle_selected_turret()
	elif key_event.is_action_pressed(&"gp_move_turret"):
		_move_selected_turret()
	elif key_event.is_action_pressed(&"gp_assign_turret"):
		_assign_selected_defender()
	elif key_event.is_action_pressed(&"gp_demolish_turret"):
		_demolish_selected_turret()
	else:
		return
	get_viewport().set_input_as_handled()


func get_selected_turret_id() -> int:
	return selected_turret_id


func get_summary() -> String:
	if selected_turret_id < 0:
		return "турель не выбрана"
	var snapshot: BuildableSnapshot = _grid.get_snapshot(selected_turret_id)
	if snapshot == null:
		return "турель не выбрана"
	return "выбрана T%d, клетка %d" % [
		selected_turret_id + 1,
		snapshot.cell_index + 1,
	]


func _unlock_turret() -> void:
	var previous_count: int = _inventory.get_unlocked_count(
		BuildableType.Id.TURRET
	)
	var count: int = _inventory.unlock(BuildableType.Id.TURRET)
	if count > previous_count:
		command_feedback.emit(&"turret_unlocked")
	else:
		command_feedback.emit(&"turret_unlock_limit")


func _place_new_turret() -> void:
	var deployed_count: int = _grid.get_count_by_type(BuildableType.Id.TURRET)
	if not _inventory.can_deploy(BuildableType.Id.TURRET, deployed_count):
		_inventory.unlock(BuildableType.Id.TURRET)
	if not _inventory.can_deploy(BuildableType.Id.TURRET, deployed_count):
		command_feedback.emit(&"turret_unlock_limit")
		return

	var target_cell: int = _grid.find_nearest_available_cell(
		_buildable_input.get_selected_cell_index()
	)
	if target_cell < 0:
		command_feedback.emit(&"turret_place_failed")
		return
	_buildable_input.select_cell(target_cell)
	var buildable_id: int = _grid.place(
		BuildableType.Id.TURRET,
		target_cell
	)
	if buildable_id < 0:
		command_feedback.emit(&"turret_place_failed")
		return
	_set_selected_turret(buildable_id)
	command_feedback.emit(&"turret_placed")


func _cycle_selected_turret() -> void:
	var ids: Array[int] = _grid.get_buildable_ids_by_type(
		BuildableType.Id.TURRET
	)
	if ids.is_empty():
		_set_selected_turret(-1)
		return
	var current_index: int = ids.find(selected_turret_id)
	var next_index: int = 0
	if current_index >= 0:
		next_index = (current_index + 1) % ids.size()
	_set_selected_turret(ids[next_index])


func _move_selected_turret() -> void:
	if selected_turret_id < 0:
		command_feedback.emit(&"turret_missing")
		return
	var target_cell: int = _grid.find_nearest_available_cell(
		_buildable_input.get_selected_cell_index(),
		selected_turret_id
	)
	if target_cell < 0:
		command_feedback.emit(&"turret_move_failed")
		return
	_buildable_input.select_cell(target_cell)
	if _grid.move(selected_turret_id, target_cell):
		command_feedback.emit(&"turret_moved")
	else:
		command_feedback.emit(&"turret_move_failed")


func _assign_selected_defender() -> void:
	if selected_turret_id < 0 or not _grid.has_buildable(selected_turret_id):
		command_feedback.emit(&"turret_missing")
		return
	_roles.request_assignment(
		_crew_selection.get_selected_defender_id(),
		CrewRole.Id.TURRET,
		selected_turret_id
	)
	command_feedback.emit(&"turret_operator_requested")


func _demolish_selected_turret() -> void:
	if selected_turret_id < 0:
		command_feedback.emit(&"turret_missing")
		return
	var removed_id: int = selected_turret_id
	if not _grid.demolish(removed_id):
		command_feedback.emit(&"turret_demolish_failed")
		return
	command_feedback.emit(&"turret_demolished")


func _select_first_available() -> void:
	var ids: Array[int] = _grid.get_buildable_ids_by_type(
		BuildableType.Id.TURRET
	)
	if ids.is_empty():
		_set_selected_turret(-1)
		return
	_set_selected_turret(ids[0])


func _set_selected_turret(buildable_id: int) -> void:
	selected_turret_id = buildable_id
	selected_turret_changed.emit(selected_turret_id)


func _on_buildable_placed(
	buildable_id: int,
	type_id: int,
	_cell_index: int
) -> void:
	if type_id == BuildableType.Id.TURRET and selected_turret_id < 0:
		_set_selected_turret(buildable_id)


func _on_buildable_demolished(
	buildable_id: int,
	type_id: int,
	_cell_index: int
) -> void:
	if type_id != BuildableType.Id.TURRET:
		return
	if buildable_id == selected_turret_id:
		_select_first_available()


func _on_grid_reset() -> void:
	_set_selected_turret(-1)
