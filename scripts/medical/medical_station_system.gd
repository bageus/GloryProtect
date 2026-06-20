class_name MedicalStationSystem
extends Node

signal station_availability_changed(is_available: bool, local_x: float)
signal healing_started(medic_id: int, target_id: int)
signal healing_progress(medic_id: int, target_id: int, remaining: float)
signal segment_restored(medic_id: int, target_id: int, amount: int)
signal healing_stopped(medic_id: int, target_id: int)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("BuildableGrid") var buildable_grid_path: NodePath
@export_node_path("CrewManager") var crew_manager_path: NodePath
@export_node_path("CrewRoleManager") var role_manager_path: NodePath
@export var balance: BuildableBalance

var _station_buildable_id: int = -1
var _station_local_x: float = 0.0
var _medic_id: int = -1
var _target_id: int = -1
var _heal_remaining: float = 0.0
var _cycle_active: bool = false

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _grid: BuildableGrid = get_node(buildable_grid_path)
@onready var _crew: CrewManager = get_node(crew_manager_path)
@onready var _roles: CrewRoleManager = get_node(role_manager_path)


func _ready() -> void:
	assert(balance != null, "MedicalStationSystem requires BuildableBalance")
	_grid.buildable_placed.connect(_on_buildable_changed)
	_grid.buildable_moved.connect(_on_buildable_moved)
	_grid.buildable_demolished.connect(_on_buildable_demolished)
	_grid.grid_reset.connect(_on_grid_reset)
	call_deferred("_sync_station")


func _physics_process(delta: float) -> void:
	if _game_flow.state != GameFlowController.RunState.RUNNING:
		return
	if _station_buildable_id < 0:
		return

	var medic: Defender = _get_active_medic()
	if medic == null:
		_stop_cycle()
		return

	if _cycle_active:
		_update_active_cycle(medic, maxf(0.0, delta))
		return

	var assignment: CrewAssignmentRuntime = _roles.get_assignment(medic.defender_id)
	if assignment == null:
		return
	if assignment.state == CrewAssignmentRuntime.State.WAITING_FOR_ACTION:
		return

	var target: Defender = _choose_healing_target(medic)
	if target == null:
		_move_defender_to(medic, _station_local_x)
		return

	_move_defender_to(medic, target.position.x)
	if absf(medic.position.x - target.position.x) <= balance.heal_range:
		_begin_cycle(medic, target)


func is_healing_cycle_active(defender_id: int) -> bool:
	return _cycle_active and _medic_id == defender_id


func has_station() -> bool:
	return _station_buildable_id >= 0


func get_station_local_x() -> float:
	return _station_local_x


func get_medic_id() -> int:
	return _medic_id


func get_target_id() -> int:
	return _target_id


func get_heal_remaining() -> float:
	return maxf(0.0, _heal_remaining)


func get_summary() -> String:
	if not has_station():
		return "медпост отсутствует"
	var owner_id: int = _roles.get_role_owner(CrewRole.Id.MEDIC)
	if owner_id < 0:
		return "медпост свободен"
	if _cycle_active:
		return "лекарь %d → %d | %.1f с" % [
			owner_id + 1,
			_target_id + 1,
			get_heal_remaining(),
		]
	return "лекарь %d ожидает/движется" % (owner_id + 1)


func _get_active_medic() -> Defender:
	var owner_id: int = _roles.get_role_owner(CrewRole.Id.MEDIC)
	if owner_id < 0:
		return null
	var assignment: CrewAssignmentRuntime = _roles.get_assignment(owner_id)
	if assignment == null:
		return null
	if assignment.current_role != CrewRole.Id.MEDIC:
		return null
	if (
		assignment.state != CrewAssignmentRuntime.State.ACTIVE
		and assignment.state != CrewAssignmentRuntime.State.WAITING_FOR_ACTION
	):
		return null
	var medic: Defender = _crew.get_defender(owner_id)
	if medic == null or not medic.health.is_alive():
		return null
	return medic


func _choose_healing_target(medic: Defender) -> Defender:
	var selected: Defender = null
	var lowest_health: int = 2147483647
	var nearest_distance: float = INF
	for candidate: Defender in _crew.get_living_defenders():
		if candidate.health.current_health >= candidate.health.max_health:
			continue
		var distance: float = absf(candidate.position.x - medic.position.x)
		if candidate.health.current_health < lowest_health:
			selected = candidate
			lowest_health = candidate.health.current_health
			nearest_distance = distance
		elif (
			candidate.health.current_health == lowest_health
			and distance < nearest_distance
		):
			selected = candidate
			nearest_distance = distance
	return selected


func _begin_cycle(medic: Defender, target: Defender) -> void:
	_medic_id = medic.defender_id
	_target_id = target.defender_id
	_heal_remaining = balance.heal_interval
	_cycle_active = true
	medic.movement.stop()
	healing_started.emit(_medic_id, _target_id)


func _update_active_cycle(medic: Defender, delta: float) -> void:
	var target: Defender = _crew.get_defender(_target_id)
	if (
		target == null
		or not target.health.is_alive()
		or target.health.current_health >= target.health.max_health
	):
		_stop_cycle()
		return

	_move_defender_to(medic, target.position.x)
	if absf(medic.position.x - target.position.x) > balance.heal_range:
		return

	medic.movement.stop()
	_heal_remaining = maxf(0.0, _heal_remaining - delta)
	healing_progress.emit(_medic_id, _target_id, _heal_remaining)
	if _heal_remaining > 0.0:
		return

	target.health.heal(balance.heal_amount)
	segment_restored.emit(_medic_id, _target_id, balance.heal_amount)
	_stop_cycle()


func _move_defender_to(defender: Defender, local_x: float) -> void:
	if (
		defender.is_moving()
		and is_equal_approx(defender.movement.get_target_x(), local_x)
	):
		return
	if absf(defender.position.x - local_x) <= defender.movement.arrival_epsilon:
		defender.movement.stop()
		return
	defender.move_to(local_x)


func _stop_cycle() -> void:
	if not _cycle_active:
		_medic_id = -1
		_target_id = -1
		_heal_remaining = 0.0
		return
	var previous_medic: int = _medic_id
	var previous_target: int = _target_id
	_cycle_active = false
	_medic_id = -1
	_target_id = -1
	_heal_remaining = 0.0
	healing_stopped.emit(previous_medic, previous_target)


func _sync_station() -> void:
	var medical_id: int = _grid.get_buildable_id_by_type(
		BuildableType.Id.MEDICAL_STATION
	)
	if medical_id < 0:
		_station_buildable_id = -1
		_station_local_x = 0.0
		_stop_cycle()
		_roles.set_dynamic_role_station(CrewRole.Id.MEDIC, false)
		station_availability_changed.emit(false, 0.0)
		return

	var snapshot: BuildableSnapshot = _grid.get_snapshot(medical_id)
	_station_buildable_id = medical_id
	_station_local_x = snapshot.local_x
	_roles.set_dynamic_role_station(
		CrewRole.Id.MEDIC,
		true,
		_station_local_x
	)
	station_availability_changed.emit(true, _station_local_x)


func _on_buildable_changed(
	_buildable_id: int,
	type_id: int,
	_cell_index: int
) -> void:
	if type_id == BuildableType.Id.MEDICAL_STATION:
		_sync_station()


func _on_buildable_moved(
	buildable_id: int,
	_previous_cell: int,
	_cell_index: int
) -> void:
	if buildable_id == _station_buildable_id:
		_sync_station()


func _on_buildable_demolished(
	_buildable_id: int,
	type_id: int,
	_cell_index: int
) -> void:
	if type_id == BuildableType.Id.MEDICAL_STATION:
		_sync_station()


func _on_grid_reset() -> void:
	_sync_station()
