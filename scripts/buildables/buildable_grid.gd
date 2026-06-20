class_name BuildableGrid
extends Node

signal buildable_placed(buildable_id: int, type_id: int, cell_index: int)
signal buildable_moved(buildable_id: int, previous_cell: int, cell_index: int)
signal buildable_demolished(buildable_id: int, type_id: int, cell_index: int)
signal grid_reset

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("BuildableInventory") var inventory_path: NodePath
@export var balance: BuildableBalance

var _buildables: Dictionary[int, BuildableRuntime] = {}
var _cell_occupants: Dictionary[int, int] = {}
var _next_buildable_id: int = 0

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _platform: PlatformController = get_node(platform_path)
@onready var _inventory: BuildableInventory = get_node(inventory_path)


func _ready() -> void:
	assert(balance != null, "BuildableGrid requires BuildableBalance")
	_game_flow.run_state_changed.connect(_on_run_state_changed)
	reset_for_run()


func place(type_id: int, cell_index: int) -> int:
	if not is_cell_available(cell_index):
		return -1
	if not _inventory.can_deploy(type_id, get_count_by_type(type_id)):
		return -1

	var runtime := BuildableRuntime.new(
		_next_buildable_id,
		type_id,
		cell_index
	)
	_next_buildable_id += 1
	_buildables[runtime.buildable_id] = runtime
	_cell_occupants[cell_index] = runtime.buildable_id
	buildable_placed.emit(runtime.buildable_id, type_id, cell_index)
	return runtime.buildable_id


func move(buildable_id: int, cell_index: int) -> bool:
	if not _buildables.has(buildable_id):
		return false
	var runtime: BuildableRuntime = _buildables[buildable_id]
	if runtime.cell_index == cell_index:
		return true
	if not is_cell_available(cell_index):
		return false

	var previous_cell: int = runtime.cell_index
	_cell_occupants.erase(previous_cell)
	runtime.cell_index = cell_index
	_cell_occupants[cell_index] = buildable_id
	buildable_moved.emit(buildable_id, previous_cell, cell_index)
	return true


func demolish(buildable_id: int) -> bool:
	if not _buildables.has(buildable_id):
		return false
	var runtime: BuildableRuntime = _buildables[buildable_id]
	_buildables.erase(buildable_id)
	_cell_occupants.erase(runtime.cell_index)
	buildable_demolished.emit(
		runtime.buildable_id,
		runtime.type_id,
		runtime.cell_index
	)
	return true


func get_buildable_id_by_type(type_id: int) -> int:
	var ids: Array[int] = _buildables.keys()
	ids.sort()
	for buildable_id: int in ids:
		if _buildables[buildable_id].type_id == type_id:
			return buildable_id
	return -1


func get_count_by_type(type_id: int) -> int:
	var count: int = 0
	for runtime: BuildableRuntime in _buildables.values():
		if runtime.type_id == type_id:
			count += 1
	return count


func is_cell_occupied(cell_index: int) -> bool:
	return _cell_occupants.has(cell_index)


func is_cell_available(cell_index: int) -> bool:
	return (
		_platform.is_valid_cell(cell_index)
		and not balance.is_reserved_cell(cell_index)
		and not is_cell_occupied(cell_index)
	)


func get_cell_local_x(cell_index: int) -> float:
	return _platform.get_cell_local_x(cell_index)


func get_snapshot(buildable_id: int) -> BuildableSnapshot:
	var runtime: BuildableRuntime = _buildables.get(buildable_id)
	if runtime == null:
		return null
	return BuildableSnapshot.new(
		runtime,
		_platform.get_cell_local_x(runtime.cell_index)
	)


func get_snapshots() -> Array[BuildableSnapshot]:
	var result: Array[BuildableSnapshot] = []
	var ids: Array[int] = _buildables.keys()
	ids.sort()
	for buildable_id: int in ids:
		result.append(get_snapshot(buildable_id))
	return result


func reset_for_run() -> void:
	_buildables.clear()
	_cell_occupants.clear()
	_next_buildable_id = 0
	grid_reset.emit()


func get_summary() -> String:
	var medical_id: int = get_buildable_id_by_type(
		BuildableType.Id.MEDICAL_STATION
	)
	if medical_id < 0:
		return "медпост не установлен"
	var snapshot: BuildableSnapshot = get_snapshot(medical_id)
	return "медпост клетка %d" % (snapshot.cell_index + 1)


func _on_run_state_changed(previous_state: int, new_state: int) -> void:
	if new_state != GameFlowController.RunState.START_DELAY:
		return
	if previous_state == GameFlowController.RunState.MANUAL_PAUSE:
		return
	reset_for_run()
