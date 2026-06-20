class_name StrategicWaveSystem
extends Node

signal group_added(group_id: int, section_id: int, enemy_count: int)
signal group_changed(group_id: int, enemy_count: int, progress: float)
signal group_removed(group_id: int)
signal groups_merged(survivor_id: int, absorbed_id: int, enemy_count: int)
signal group_split(source_id: int, new_group_ids: Array[int])
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
		),
		_shield.get_section_count(),
		balance.mutation_cooldown
	)
	_next_group_id += 1
	_groups.append(runtime)
	group_added.emit(runtime.group_id, section_id, runtime.enemy_count)
	return runtime.group_id


func get_active_group_count() -> int:
	return _groups.size()


func get_available_group_slots() -> int:
	return maxi(0, balance.max_active_groups - _groups.size())


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


func merge_groups(first_group_id: int, second_group_id: int) -> int:
	if first_group_id == second_group_id:
		return -1
	var first_index: int = _find_group_index(first_group_id)
	var second_index: int = _find_group_index(second_group_id)
	if first_index < 0 or second_index < 0:
		return -1

	var first: StrategicGroupRuntime = _groups[first_index]
	var second: StrategicGroupRuntime = _groups[second_index]
	if not _can_mutate(first) or not _can_mutate(second):
		return -1

	var survivor: StrategicGroupRuntime = first
	var absorbed: StrategicGroupRuntime = second
	var absorbed_index: int = second_index
	if second.enemy_count > first.enemy_count:
		survivor = second
		absorbed = first
		absorbed_index = first_index

	var first_weight: float = float(survivor.enemy_count)
	var second_weight: float = float(absorbed.enemy_count)
	var total_weight: float = first_weight + second_weight
	var merged_angle_vector: Vector2 = (
		Vector2.from_angle(survivor.map_angle) * first_weight
		+ Vector2.from_angle(absorbed.map_angle) * second_weight
	)
	if merged_angle_vector.length_squared() > 0.0001:
		survivor.map_angle = wrapf(merged_angle_vector.angle(), 0.0, TAU)
	survivor.map_distance = (
		survivor.map_distance * first_weight
		+ absorbed.map_distance * second_weight
	) / total_weight

	var remaining_duration: float = (
		_get_remaining_travel_duration(survivor) * first_weight
		+ _get_remaining_travel_duration(absorbed) * second_weight
	) / total_weight
	survivor.enemy_count += absorbed.enemy_count
	survivor.initial_enemy_count += absorbed.initial_enemy_count
	survivor.lane_offset = 0.0
	survivor.replan_route(
		survivor.section_id,
		_shield.get_section_count(),
		remaining_duration,
		balance.mutation_cooldown
	)

	_groups.remove_at(absorbed_index)
	group_removed.emit(absorbed.group_id)
	groups_merged.emit(
		survivor.group_id,
		absorbed.group_id,
		survivor.enemy_count
	)
	group_changed.emit(
		survivor.group_id,
		survivor.enemy_count,
		survivor.progress
	)
	return survivor.group_id


func split_group(
	group_id: int,
	target_sections: Array[int],
	enemy_counts: Array[int]
) -> Array[int]:
	var empty_result: Array[int] = []
	if target_sections.size() < 2:
		return empty_result
	if target_sections.size() != enemy_counts.size():
		return empty_result
	if target_sections.size() - 1 > get_available_group_slots():
		return empty_result

	var source_index: int = _find_group_index(group_id)
	if source_index < 0:
		return empty_result
	var source: StrategicGroupRuntime = _groups[source_index]
	if not _can_mutate(source):
		return empty_result

	var count_sum: int = 0
	for index: int in range(enemy_counts.size()):
		if enemy_counts[index] <= 0:
			return empty_result
		if not _shield.is_valid_section(target_sections[index]):
			return empty_result
		count_sum += enemy_counts[index]
	if count_sum != source.enemy_count:
		return empty_result

	var source_angle: float = source.map_angle
	var source_distance: float = source.map_distance
	var source_duration: float = _get_remaining_travel_duration(source)
	_groups.remove_at(source_index)
	group_removed.emit(source.group_id)

	var new_group_ids: Array[int] = []
	for index: int in range(target_sections.size()):
		var runtime: StrategicGroupRuntime = _create_runtime_at_position(
			target_sections[index],
			enemy_counts[index],
			source_duration,
			source_angle,
			source_distance
		)
		_groups.append(runtime)
		new_group_ids.append(runtime.group_id)
		group_added.emit(
			runtime.group_id,
			runtime.section_id,
			runtime.enemy_count
		)
	group_split.emit(source.group_id, new_group_ids)
	return new_group_ids


func reset_for_run() -> void:
	for runtime: StrategicGroupRuntime in _groups:
		group_removed.emit(runtime.group_id)
	_groups.clear()
	_next_group_id = 0
	groups_reset.emit()


func _create_runtime_at_position(
	section_id: int,
	enemy_count: int,
	travel_duration: float,
	map_angle: float,
	map_distance: float
) -> StrategicGroupRuntime:
	var runtime := StrategicGroupRuntime.new(
		_next_group_id,
		section_id,
		enemy_count,
		travel_duration,
		0.0,
		_shield.get_section_count(),
		balance.mutation_cooldown
	)
	_next_group_id += 1
	runtime.map_angle = wrapf(map_angle, 0.0, TAU)
	runtime.map_distance = clampf(map_distance, 0.0, 1.0)
	runtime.replan_route(
		section_id,
		_shield.get_section_count(),
		travel_duration,
		balance.mutation_cooldown
	)
	return runtime


func _update_groups(delta: float) -> void:
	var remove_indices: Array[int] = []
	for index: int in range(_groups.size()):
		var runtime: StrategicGroupRuntime = _groups[index]
		runtime.mutation_cooldown_remaining = maxf(
			0.0,
			runtime.mutation_cooldown_remaining - delta
		)
		if runtime.state == StrategicGroupRuntime.State.TRAVELING:
			_update_travel(runtime, delta)
		else:
			_update_impact(runtime, delta)
		if runtime.enemy_count <= 0:
			remove_indices.append(index)

	remove_indices.reverse()
	for remove_index: int in remove_indices:
		var removed: StrategicGroupRuntime = _groups[remove_index]
		_groups.remove_at(remove_index)
		group_removed.emit(removed.group_id)


func _update_travel(runtime: StrategicGroupRuntime, delta: float) -> void:
	runtime.route_elapsed += delta
	var route_progress: float = clampf(
		runtime.route_elapsed / runtime.travel_duration,
		0.0,
		1.0
	)
	var angle_delta: float = wrapf(
		runtime.route_target_angle - runtime.route_start_angle + PI,
		0.0,
		TAU
	) - PI
	runtime.map_angle = wrapf(
		runtime.route_start_angle + angle_delta * route_progress,
		0.0,
		TAU
	)
	runtime.map_distance = lerpf(
		runtime.route_start_distance,
		0.0,
		route_progress
	)
	runtime.progress = 1.0 - runtime.map_distance
	if route_progress >= 1.0:
		runtime.state = StrategicGroupRuntime.State.IMPACTING
		runtime.map_angle = runtime.route_target_angle
		runtime.map_distance = 0.0
		runtime.progress = 1.0
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


func _can_mutate(runtime: StrategicGroupRuntime) -> bool:
	return (
		runtime.state == StrategicGroupRuntime.State.TRAVELING
		and runtime.mutation_cooldown_remaining <= 0.0
	)


func _find_group_index(group_id: int) -> int:
	for index: int in range(_groups.size()):
		if _groups[index].group_id == group_id:
			return index
	return -1


func _get_remaining_travel_duration(runtime: StrategicGroupRuntime) -> float:
	if runtime.state != StrategicGroupRuntime.State.TRAVELING:
		return 0.01
	var remaining_fraction: float = 1.0 - clampf(
		runtime.route_elapsed / runtime.travel_duration,
		0.0,
		1.0
	)
	return maxf(0.01, runtime.travel_duration * remaining_fraction)


func _on_run_state_changed(previous_state: int, new_state: int) -> void:
	if new_state != GameFlowController.RunState.START_DELAY:
		return
	if previous_state == GameFlowController.RunState.MANUAL_PAUSE:
		return
	reset_for_run()
