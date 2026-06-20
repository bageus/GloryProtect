class_name StrategicWaveSystem
extends Node

signal group_added(group_id: int, section_id: int, enemy_count: int)
signal group_changed(group_id: int, enemy_count: int, progress: float)
signal group_removed(group_id: int)
signal strategic_enemy_impacted(section_id: int, damage: float)
signal groups_reset

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("ShieldSystem") var shield_system_path: NodePath
@export var balance: StrategicWaveBalance

var _groups: Array[StrategicGroupRuntime] = []
var _next_group_id: int = 0

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _shield: ShieldSystem = get_node(shield_system_path)


func _ready() -> void:
	assert(balance != null, "StrategicWaveSystem requires StrategicWaveBalance")
	_game_flow.run_state_changed.connect(_on_run_state_changed)


func _physics_process(delta: float) -> void:
	if _game_flow.state != GameFlowController.RunState.RUNNING:
		return
	_update_groups(maxf(0.0, delta))


func add_group(
	section_id: int,
	enemy_count: int,
	travel_duration: float,
	lane_offset: float
) -> int:
	if not _shield.is_valid_section(section_id) or enemy_count <= 0:
		return -1
	if _groups.size() >= balance.max_active_groups:
		return -1

	var runtime := StrategicGroupRuntime.new(
		_next_group_id,
		section_id,
		enemy_count,
		travel_duration,
		clampf(
			lane_offset,
			-balance.maximum_lane_offset,
			balance.maximum_lane_offset
		)
	)
	_next_group_id += 1
	_groups.append(runtime)
	group_added.emit(runtime.group_id, section_id, runtime.enemy_count)
	return runtime.group_id


func get_active_group_count() -> int:
	return _groups.size()


func get_total_enemy_count() -> int:
	var total: int = 0
	for runtime: StrategicGroupRuntime in _groups:
		total += runtime.enemy_count
	return total


func get_group_snapshots() -> Array[StrategicGroupSnapshot]:
	var snapshots: Array[StrategicGroupSnapshot] = []
	for runtime: StrategicGroupRuntime in _groups:
		snapshots.append(StrategicGroupSnapshot.new(runtime))
	return snapshots


func reset_for_run() -> void:
	for runtime: StrategicGroupRuntime in _groups:
		group_removed.emit(runtime.group_id)
	_groups.clear()
	_next_group_id = 0
	groups_reset.emit()


func _update_groups(delta: float) -> void:
	var remove_indices: Array[int] = []
	for index: int in range(_groups.size()):
		var runtime: StrategicGroupRuntime = _groups[index]
		if runtime.state == StrategicGroupRuntime.State.TRAVELING:
			_update_travel(runtime, delta)
		else:
			_update_impact(runtime, delta)
		if runtime.enemy_count <= 0:
			remove_indices.append(index)

	for reverse_index: int in range(remove_indices.size() - 1, -1, -1):
		var remove_index: int = remove_indices[reverse_index]
		var removed: StrategicGroupRuntime = _groups[remove_index]
		_groups.remove_at(remove_index)
		group_removed.emit(removed.group_id)


func _update_travel(runtime: StrategicGroupRuntime, delta: float) -> void:
	runtime.progress = clampf(
		runtime.progress + delta / runtime.travel_duration,
		0.0,
		1.0
	)
	if runtime.progress >= 1.0:
		runtime.state = StrategicGroupRuntime.State.IMPACTING
		runtime.impact_remaining = 0.0
	group_changed.emit(runtime.group_id, runtime.enemy_count, runtime.progress)


func _update_impact(runtime: StrategicGroupRuntime, delta: float) -> void:
	runtime.impact_remaining -= delta
	while runtime.impact_remaining <= 0.0 and runtime.enemy_count > 0:
		_shield.apply_damage(runtime.section_id, balance.damage_per_enemy)
		runtime.enemy_count -= 1
		strategic_enemy_impacted.emit(
			runtime.section_id,
			balance.damage_per_enemy
		)
		runtime.impact_remaining += balance.impact_interval
	group_changed.emit(runtime.group_id, runtime.enemy_count, 1.0)


func _on_run_state_changed(previous_state: int, new_state: int) -> void:
	if new_state != GameFlowController.RunState.START_DELAY:
		return
	if previous_state == GameFlowController.RunState.MANUAL_PAUSE:
		return
	reset_for_run()
