class_name StrategicGroupMutationController
extends Node

signal mutation_check_completed(changed: bool)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("RunDifficulty") var run_difficulty_path: NodePath
@export_node_path("ShieldSystem") var shield_system_path: NodePath
@export_node_path("StrategicWaveSystem") var wave_system_path: NodePath
@export var balance: StrategicWaveBalance

var _check_remaining: float = 0.0
var _rng := RandomNumberGenerator.new()

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _difficulty: RunDifficulty = get_node(run_difficulty_path)
@onready var _shield: ShieldSystem = get_node(shield_system_path)
@onready var _waves: StrategicWaveSystem = get_node(wave_system_path)


func _ready() -> void:
	assert(
		balance != null,
		"StrategicGroupMutationController requires StrategicWaveBalance"
	)
	_rng.randomize()
	_game_flow.run_state_changed.connect(_on_run_state_changed)
	reset_for_run()


func _physics_process(delta: float) -> void:
	if _game_flow.state != GameFlowController.RunState.RUNNING:
		return
	_check_remaining -= maxf(0.0, delta)
	if _check_remaining > 0.0:
		return
	run_mutation_check_now()
	_check_remaining = balance.mutation_check_interval


func get_check_remaining() -> float:
	return maxf(0.0, _check_remaining)


func set_debug_seed(value: int) -> void:
	_rng.seed = value


func reset_for_run() -> void:
	_check_remaining = balance.mutation_check_interval


func run_mutation_check_now() -> bool:
	if _game_flow.state != GameFlowController.RunState.RUNNING:
		mutation_check_completed.emit(false)
		return false
	var changed: bool = _try_merge()
	if not changed:
		changed = _try_split()
	mutation_check_completed.emit(changed)
	return changed


func _try_merge() -> bool:
	var snapshots: Array[StrategicGroupSnapshot] = _waves.get_group_snapshots()
	var best_first_id: int = -1
	var best_second_id: int = -1
	var best_distance: float = INF

	for first_index: int in range(snapshots.size()):
		var first: StrategicGroupSnapshot = snapshots[first_index]
		if first.is_impacting or not first.mutation_ready:
			continue
		for second_index: int in range(first_index + 1, snapshots.size()):
			var second: StrategicGroupSnapshot = snapshots[second_index]
			if second.is_impacting or not second.mutation_ready:
				continue
			var angle_distance: float = _get_angle_distance(
				first.map_angle,
				second.map_angle
			)
			var radial_distance: float = absf(
				first.map_distance - second.map_distance
			)
			if angle_distance > balance.merge_angle_tolerance:
				continue
			if radial_distance > balance.merge_distance_tolerance:
				continue
			var combined_distance: float = angle_distance + radial_distance
			if combined_distance >= best_distance:
				continue
			best_distance = combined_distance
			best_first_id = first.group_id
			best_second_id = second.group_id

	if best_first_id < 0:
		return false
	return _waves.merge_groups(best_first_id, best_second_id) >= 0


func _try_split() -> bool:
	var split_chance: float = balance.get_split_chance(
		_difficulty.get_normalized()
	)
	if split_chance <= 0.0 or _rng.randf() >= split_chance:
		return false
	var candidates: Array[StrategicGroupSnapshot] = []
	for snapshot: StrategicGroupSnapshot in _waves.get_group_snapshots():
		if _is_split_candidate(snapshot):
			candidates.append(snapshot)
	if candidates.is_empty():
		return false

	var source: StrategicGroupSnapshot = candidates[
		_rng.randi_range(0, candidates.size() - 1)
	]
	var maximum_parts: int = mini(
		balance.maximum_split_parts,
		source.enemy_count
	)
	maximum_parts = mini(
		maximum_parts,
		_waves.get_available_group_slots() + 1
	)
	if maximum_parts < 2:
		return false

	var part_count: int = _rng.randi_range(2, maximum_parts)
	var enemy_counts: Array[int] = _split_enemy_count(
		source.enemy_count,
		part_count
	)
	var target_sections: Array[int] = _choose_split_targets(
		source.section_id,
		part_count
	)
	return not _waves.split_group(
		source.group_id,
		target_sections,
		enemy_counts
	).is_empty()


func _is_split_candidate(snapshot: StrategicGroupSnapshot) -> bool:
	return (
		not snapshot.is_impacting
		and snapshot.mutation_ready
		and snapshot.enemy_count >= balance.minimum_split_enemy_count
		and snapshot.progress >= balance.split_min_progress
		and snapshot.progress <= balance.split_max_progress
	)


func _split_enemy_count(total_count: int, part_count: int) -> Array[int]:
	var counts: Array[int] = []
	for _index: int in range(part_count):
		counts.append(1)
	var remaining: int = total_count - part_count
	while remaining > 0:
		counts[_rng.randi_range(0, part_count - 1)] += 1
		remaining -= 1
	return counts


func _choose_split_targets(source_section: int, part_count: int) -> Array[int]:
	var targets: Array[int] = [source_section]
	var used_redirects: Array[int] = [source_section]
	for _index: int in range(1, part_count):
		var target: int = source_section
		if (
			_shield.get_section_count() > 1
			and _rng.randf() <= balance.split_redirect_chance
		):
			target = _choose_redirect_target(source_section, used_redirects)
			if not used_redirects.has(target):
				used_redirects.append(target)
		targets.append(target)
	return targets


func _choose_redirect_target(
	source_section: int,
	used_sections: Array[int]
) -> int:
	var preferred: Array[int] = []
	var fallback: Array[int] = []
	for section_id: int in range(_shield.get_section_count()):
		if section_id == source_section:
			continue
		fallback.append(section_id)
		if not used_sections.has(section_id):
			preferred.append(section_id)
	var candidates: Array[int] = preferred
	if candidates.is_empty():
		candidates = fallback
	if candidates.is_empty():
		return source_section
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _get_angle_distance(first_angle: float, second_angle: float) -> float:
	return absf(wrapf(first_angle - second_angle + PI, 0.0, TAU) - PI)


func _on_run_state_changed(previous_state: int, new_state: int) -> void:
	if new_state != GameFlowController.RunState.START_DELAY:
		return
	if previous_state == GameFlowController.RunState.MANUAL_PAUSE:
		return
	reset_for_run()
