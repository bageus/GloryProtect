class_name TurretSystem
extends Node

signal turret_registered(buildable_id: int)
signal turret_removed(buildable_id: int)
signal shot_started(buildable_id: int, operator_id: int, enemy_id: int)
signal shot_completed(buildable_id: int, enemy_id: int, hit: bool)
signal shot_cancelled(buildable_id: int, enemy_id: int)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("BuildableGrid") var buildable_grid_path: NodePath
@export_node_path("CrewManager") var crew_manager_path: NodePath
@export_node_path("CrewRoleManager") var role_manager_path: NodePath
@export_node_path("BoardingEnemyRegistry") var enemy_registry_path: NodePath
@export var balance: BuildableBalance

var _runtimes: Dictionary[int, TurretRuntime] = {}
var _selector: TurretTargetSelector = TurretTargetSelector.new()

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _platform: PlatformController = get_node(platform_path)
@onready var _grid: BuildableGrid = get_node(buildable_grid_path)
@onready var _crew: CrewManager = get_node(crew_manager_path)
@onready var _roles: CrewRoleManager = get_node(role_manager_path)
@onready var _enemies: BoardingEnemyRegistry = get_node(enemy_registry_path)


func _ready() -> void:
	assert(balance != null, "TurretSystem requires BuildableBalance")
	_grid.buildable_placed.connect(_on_buildable_placed)
	_grid.buildable_moved.connect(_on_buildable_moved)
	_grid.buildable_demolished.connect(_on_buildable_demolished)
	_grid.grid_reset.connect(_on_grid_reset)
	call_deferred("_sync_turrets")


func _physics_process(delta: float) -> void:
	if _game_flow.state != GameFlowController.RunState.RUNNING:
		return
	for runtime: TurretRuntime in _runtimes.values():
		_update_runtime(runtime, maxf(0.0, delta))


func get_turret_ids() -> Array[int]:
	var ids: Array[int] = _runtimes.keys()
	ids.sort()
	return ids


func has_turret(buildable_id: int) -> bool:
	return _runtimes.has(buildable_id)


func is_firing(buildable_id: int) -> bool:
	var runtime: TurretRuntime = _runtimes.get(buildable_id)
	return runtime != null and runtime.firing


func get_operator_id(buildable_id: int) -> int:
	var runtime: TurretRuntime = _runtimes.get(buildable_id)
	if runtime == null:
		return -1
	return runtime.operator_id


func get_target_enemy_id(buildable_id: int) -> int:
	var runtime: TurretRuntime = _runtimes.get(buildable_id)
	if runtime == null:
		return -1
	return runtime.target_enemy_id


func get_shot_remaining(buildable_id: int) -> float:
	var runtime: TurretRuntime = _runtimes.get(buildable_id)
	if runtime == null:
		return 0.0
	return maxf(0.0, runtime.shot_remaining)


func get_summary() -> String:
	var parts := PackedStringArray()
	for buildable_id: int in get_turret_ids():
		var runtime: TurretRuntime = _runtimes[buildable_id]
		var owner_id: int = _roles.get_role_owner(
			CrewRole.Id.TURRET,
			buildable_id
		)
		var state_text: String = "без оператора"
		if runtime.firing:
			state_text = "цель %d %.1fс" % [
				runtime.target_enemy_id + 1,
				runtime.shot_remaining,
			]
		elif owner_id >= 0:
			state_text = "оператор %d" % (owner_id + 1)
		parts.append("T%d %s" % [buildable_id + 1, state_text])
	if parts.is_empty():
		return "нет турелей"
	return " | ".join(parts)


func _update_runtime(runtime: TurretRuntime, delta: float) -> void:
	runtime.cooldown_remaining = maxf(
		0.0,
		runtime.cooldown_remaining - delta
	)
	var operator_id: int = _get_operational_operator_id(runtime.buildable_id)
	if operator_id < 0:
		_cancel_shot(runtime)
		runtime.operator_id = -1
		return
	if runtime.operator_id >= 0 and runtime.operator_id != operator_id:
		_cancel_shot(runtime)
	runtime.operator_id = operator_id

	if runtime.firing:
		runtime.shot_remaining = maxf(0.0, runtime.shot_remaining - delta)
		if runtime.shot_remaining <= 0.0:
			_complete_shot(runtime)
		return

	var assignment: CrewAssignmentRuntime = _roles.get_assignment(operator_id)
	if assignment == null:
		return
	if assignment.state != CrewAssignmentRuntime.State.ACTIVE:
		return
	if runtime.cooldown_remaining > 0.0:
		return

	var snapshot: BuildableSnapshot = _grid.get_snapshot(runtime.buildable_id)
	if snapshot == null:
		return
	var target: BoardingEnemy = _selector.get_nearest_target(
		_enemies,
		_get_turret_world_origin(snapshot),
		balance.turret_range
	)
	if target != null:
		_begin_shot(runtime, target)


func _get_operational_operator_id(buildable_id: int) -> int:
	var owner_id: int = _roles.get_role_owner(
		CrewRole.Id.TURRET,
		buildable_id
	)
	if owner_id < 0:
		return -1
	var defender: Defender = _crew.get_defender(owner_id)
	if defender == null or not defender.health.is_alive():
		return -1
	var assignment: CrewAssignmentRuntime = _roles.get_assignment(owner_id)
	if assignment == null:
		return -1
	if assignment.current_role != CrewRole.Id.TURRET:
		return -1
	if assignment.current_station_id != buildable_id:
		return -1
	if (
		assignment.state != CrewAssignmentRuntime.State.ACTIVE
		and assignment.state != CrewAssignmentRuntime.State.WAITING_FOR_ACTION
	):
		return -1
	return owner_id


func _begin_shot(runtime: TurretRuntime, target: BoardingEnemy) -> void:
	runtime.begin_shot(target.enemy_id, balance.turret_shot_windup)
	_roles.set_external_role_action_active(
		runtime.operator_id,
		CrewRole.Id.TURRET,
		true
	)
	shot_started.emit(
		runtime.buildable_id,
		runtime.operator_id,
		target.enemy_id
	)


func _complete_shot(runtime: TurretRuntime) -> void:
	var target_enemy_id: int = runtime.target_enemy_id
	var target: BoardingEnemy = _enemies.get_enemy(target_enemy_id)
	var hit: bool = false
	if target != null and _selector.is_still_targetable(target):
		target.health.apply_damage(balance.turret_damage)
		hit = true
	_roles.set_external_role_action_active(
		runtime.operator_id,
		CrewRole.Id.TURRET,
		false
	)
	runtime.finish_shot(balance.turret_shot_cooldown)
	shot_completed.emit(runtime.buildable_id, target_enemy_id, hit)


func _cancel_shot(runtime: TurretRuntime) -> void:
	if not runtime.firing:
		return
	var previous_target: int = runtime.target_enemy_id
	if runtime.operator_id >= 0:
		_roles.set_external_role_action_active(
			runtime.operator_id,
			CrewRole.Id.TURRET,
			false
		)
	runtime.cancel_shot()
	shot_cancelled.emit(runtime.buildable_id, previous_target)


func _get_turret_world_origin(snapshot: BuildableSnapshot) -> Vector2:
	return _platform.to_global(
		Vector2(
			snapshot.local_x,
			balance.turret_bottom_y - balance.turret_height * 0.5
		)
	)


func _register_turret(buildable_id: int) -> void:
	if _runtimes.has(buildable_id):
		return
	var snapshot: BuildableSnapshot = _grid.get_snapshot(buildable_id)
	if snapshot == null or snapshot.type_id != BuildableType.Id.TURRET:
		return
	_runtimes[buildable_id] = TurretRuntime.new(buildable_id)
	_roles.set_dynamic_role_station(
		CrewRole.Id.TURRET,
		true,
		snapshot.local_x,
		buildable_id,
		false
	)
	turret_registered.emit(buildable_id)


func _remove_turret(buildable_id: int) -> void:
	var runtime: TurretRuntime = _runtimes.get(buildable_id)
	if runtime != null:
		_cancel_shot(runtime)
	_roles.set_dynamic_role_station(
		CrewRole.Id.TURRET,
		false,
		0.0,
		buildable_id,
		false
	)
	_runtimes.erase(buildable_id)
	turret_removed.emit(buildable_id)


func _sync_turrets() -> void:
	for buildable_id: int in _grid.get_buildable_ids_by_type(
		BuildableType.Id.TURRET
	):
		_register_turret(buildable_id)


func _on_buildable_placed(
	buildable_id: int,
	type_id: int,
	_cell_index: int
) -> void:
	if type_id == BuildableType.Id.TURRET:
		_register_turret(buildable_id)


func _on_buildable_moved(
	buildable_id: int,
	_previous_cell: int,
	_cell_index: int
) -> void:
	if not _runtimes.has(buildable_id):
		return
	var snapshot: BuildableSnapshot = _grid.get_snapshot(buildable_id)
	if snapshot == null:
		return
	_roles.set_dynamic_role_station(
		CrewRole.Id.TURRET,
		true,
		snapshot.local_x,
		buildable_id,
		true
	)


func _on_buildable_demolished(
	buildable_id: int,
	type_id: int,
	_cell_index: int
) -> void:
	if type_id == BuildableType.Id.TURRET:
		_remove_turret(buildable_id)


func _on_grid_reset() -> void:
	var ids: Array[int] = get_turret_ids()
	for buildable_id: int in ids:
		_remove_turret(buildable_id)
	_runtimes.clear()
