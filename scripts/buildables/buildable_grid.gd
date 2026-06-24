class_name BuildableGrid
extends Node

signal buildable_placed(buildable_id: int, type_id: int, cell_index: int)
signal buildable_moved(buildable_id: int, previous_cell: int, cell_index: int)
signal buildable_demolished(buildable_id: int, type_id: int, cell_index: int)
signal grid_reset

const REASON_INVALID_CELL: StringName = &"invalid_cell"
const REASON_UNSUPPORTED_TYPE: StringName = &"unsupported_type"
const REASON_CELL_NOT_ALLOWED: StringName = &"cell_not_allowed"
const REASON_CELL_OCCUPIED: StringName = &"cell_occupied"
const REASON_BUILDABLE_LOCKED: StringName = &"buildable_locked"
const REASON_DEPLOYMENT_LIMIT: StringName = &"deployment_limit"

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
	if get_place_unavailability_reason(type_id, cell_index) != &"":
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
	if get_cell_unavailability_reason(
		runtime.type_id,
		cell_index,
		buildable_id
	) != &"":
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


func has_buildable(buildable_id: int) -> bool:
	return _buildables.has(buildable_id)


func get_buildable_id_at_cell(cell_index: int) -> int:
	return int(_cell_occupants.get(cell_index, -1))


func get_buildable_id_by_type(type_id: int) -> int:
	var ids: Array[int] = get_buildable_ids_by_type(type_id)
	return -1 if ids.is_empty() else ids[0]


func get_buildable_ids_by_type(type_id: int) -> Array[int]:
	var result: Array[int] = []
	var ids: Array[int] = _buildables.keys()
	ids.sort()
	for buildable_id: int in ids:
		if _buildables[buildable_id].type_id == type_id:
			result.append(buildable_id)
	return result


func get_count_by_type(type_id: int) -> int:
	return get_buildable_ids_by_type(type_id).size()


func is_cell_occupied(cell_index: int) -> bool:
	return _cell_occupants.has(cell_index)


func is_cell_available(cell_index: int) -> bool:
	return (
		is_cell_available_for_type(BuildableType.Id.TURRET, cell_index)
		or is_cell_available_for_type(
			BuildableType.Id.MEDICAL_STATION,
			cell_index
		)
	)


func is_cell_available_for_type(type_id: int, cell_index: int) -> bool:
	return get_cell_unavailability_reason(type_id, cell_index) == &""


func get_cell_unavailability_reason(
	type_id: int,
	cell_index: int,
	ignored_buildable_id: int = -1
) -> StringName:
	if not _platform.is_valid_cell(cell_index):
		return REASON_INVALID_CELL
	if type_id == BuildableType.Id.MEDICAL_STATION:
		if not balance.is_medical_cell(cell_index):
			return REASON_CELL_NOT_ALLOWED
	elif type_id == BuildableType.Id.TURRET:
		if not balance.is_turret_cell(cell_index):
			return REASON_CELL_NOT_ALLOWED
	else:
		return REASON_UNSUPPORTED_TYPE
	if not _cell_occupants.has(cell_index):
		return &""
	if int(_cell_occupants[cell_index]) == ignored_buildable_id:
		return &""
	return REASON_CELL_OCCUPIED


func get_place_unavailability_reason(
	type_id: int,
	cell_index: int
) -> StringName:
	var cell_reason := get_cell_unavailability_reason(type_id, cell_index)
	if cell_reason != &"":
		return cell_reason
	if not _inventory.is_unlocked(type_id):
		return REASON_BUILDABLE_LOCKED
	if not _inventory.can_deploy(type_id, get_count_by_type(type_id)):
		return REASON_DEPLOYMENT_LIMIT
	return &""


func find_nearest_available_cell(
	preferred_cell: int,
	ignored_buildable_id: int = -1
) -> int:
	return find_nearest_available_cell_for_type(
		BuildableType.Id.TURRET,
		preferred_cell,
		ignored_buildable_id
	)


func find_nearest_available_cell_for_type(
	type_id: int,
	preferred_cell: int,
	ignored_buildable_id: int = -1
) -> int:
	var candidates: Array[int] = []
	if type_id == BuildableType.Id.MEDICAL_STATION:
		candidates = balance.get_medical_cell_indices()
	elif type_id == BuildableType.Id.TURRET:
		candidates = balance.turret_cell_indices.duplicate()
	else:
		return -1

	var best_cell: int = -1
	var best_distance: int = 2147483647
	for cell_index: int in candidates:
		if get_cell_unavailability_reason(
			type_id,
			cell_index,
			ignored_buildable_id
		) != &"":
			continue
		var distance: int = absi(cell_index - preferred_cell)
		if distance < best_distance:
			best_distance = distance
			best_cell = cell_index
	return best_cell


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
	var medical_text: String = "медпост не установлен"
	if medical_id >= 0:
		var snapshot: BuildableSnapshot = get_snapshot(medical_id)
		medical_text = "медпост клетка %d" % (snapshot.cell_index + 1)
	return "%s | турелей %d" % [
		medical_text,
		get_count_by_type(BuildableType.Id.TURRET),
	]


func _on_run_state_changed(previous_state: int, new_state: int) -> void:
	if new_state != GameFlowController.RunState.START_DELAY:
		return
	if previous_state == GameFlowController.RunState.MANUAL_PAUSE:
		return
	reset_for_run()
