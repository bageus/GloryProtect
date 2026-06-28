class_name StrategicWaveDirector
extends Node

signal wave_spawned(
	wave_number: int,
	total_enemy_count: int,
	target_section_count: int
)
signal schedule_reset

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("RunDifficulty") var run_difficulty_path: NodePath
@export_node_path("ShieldSystem") var shield_system_path: NodePath
@export_node_path("StrategicWaveSystem") var wave_system_path: NodePath
@export var balance: StrategicWaveBalance

var _wave_remaining: float = 0.0
var _wave_number: int = 0
var _rng := RandomNumberGenerator.new()

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _difficulty: RunDifficulty = get_node(run_difficulty_path)
@onready var _shield: ShieldSystem = get_node(shield_system_path)
@onready var _waves: StrategicWaveSystem = get_node(wave_system_path)


func _ready() -> void:
	assert(balance != null, "StrategicWaveDirector requires StrategicWaveBalance")
	_rng.randomize()
	_game_flow.run_state_changed.connect(_on_run_state_changed)
	reset_for_run()


func _physics_process(delta: float) -> void:
	if _game_flow.state != GameFlowController.RunState.RUNNING:
		return
	if _waves.get_active_group_count() >= balance.max_active_groups:
		return

	var current_interval: float = get_current_wave_interval()
	_wave_remaining = minf(_wave_remaining, current_interval)
	_wave_remaining -= maxf(0.0, delta)
	if _wave_remaining > 0.0:
		return

	spawn_wave_now()
	_wave_remaining = current_interval


func get_wave_number() -> int:
	return _wave_number


func get_wave_remaining() -> float:
	return maxf(0.0, _wave_remaining)


func get_current_difficulty() -> float:
	return _difficulty.get_normalized()


func get_current_overtime_tier() -> int:
	return _difficulty.get_overtime_tier()


func get_current_wave_interval() -> float:
	return balance.get_wave_interval(get_current_difficulty())


func get_current_wave_size() -> int:
	return balance.get_wave_size(
		get_current_difficulty(),
		get_current_overtime_tier()
	)


func get_current_travel_duration() -> float:
	return balance.get_travel_duration(get_current_difficulty())


func get_current_target_section_count() -> int:
	return balance.get_target_section_count(
		get_current_difficulty(),
		_shield.get_section_count()
	)


func set_debug_seed(value: int) -> void:
	_rng.seed = value


func spawn_wave_now() -> int:
	var total_enemy_count: int = get_current_wave_size()
	var requested_targets: int = get_current_target_section_count()
	var available_slots: int = (
		balance.max_active_groups - _waves.get_active_group_count()
	)
	var target_count: int = mini(
		mini(requested_targets, total_enemy_count),
		available_slots
	)
	if target_count <= 0:
		return 0

	var target_sections: Array[int] = _choose_unique_sections(target_count)
	var counts: Array[int] = _split_enemy_count(
		total_enemy_count,
		target_sections.size()
	)
	var travel_duration: float = get_current_travel_duration()
	var created_count: int = 0

	for index: int in range(target_sections.size()):
		var lane_offset: float = _rng.randf_range(
			-balance.maximum_lane_offset,
			balance.maximum_lane_offset
		)
		var group_id: int = _waves.add_group(
			target_sections[index],
			counts[index],
			travel_duration,
			lane_offset
		)
		if group_id >= 0:
			created_count += counts[index]

	if created_count <= 0:
		return 0
	_wave_number += 1
	wave_spawned.emit(_wave_number, created_count, target_sections.size())
	return created_count


func reset_for_run() -> void:
	_wave_number = 0
	_wave_remaining = balance.first_wave_delay
	schedule_reset.emit()


func _choose_unique_sections(count: int) -> Array[int]:
	var sections: Array[int] = []
	for section_id: int in range(_shield.get_section_count()):
		sections.append(section_id)
	for index: int in range(sections.size() - 1, 0, -1):
		var swap_index: int = _rng.randi_range(0, index)
		var temporary: int = sections[index]
		sections[index] = sections[swap_index]
		sections[swap_index] = temporary

	var selected: Array[int] = []
	var selected_count: int = mini(count, sections.size())
	for index: int in range(selected_count):
		selected.append(sections[index])
	return selected


func _split_enemy_count(total_count: int, group_count: int) -> Array[int]:
	var counts: Array[int] = []
	if group_count <= 0:
		return counts
	for _index: int in range(group_count):
		counts.append(1)
	var remaining: int = total_count - group_count
	while remaining > 0:
		counts[_rng.randi_range(0, group_count - 1)] += 1
		remaining -= 1
	return counts


func _on_run_state_changed(previous_state: int, new_state: int) -> void:
	if new_state != GameFlowController.RunState.START_DELAY:
		return
	if previous_state == GameFlowController.RunState.MANUAL_PAUSE:
		return
	reset_for_run()
