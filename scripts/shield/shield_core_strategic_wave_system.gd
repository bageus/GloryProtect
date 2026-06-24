class_name ShieldCoreStrategicWaveSystem
extends StrategicWaveSystem

signal strategic_enemies_retargeted(section_id: int, enemy_count: int)
signal strategic_rows_destroyed(section_id: int, enemy_count: int)

var _effect_rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	_effect_rng.randomize()


func set_effect_random_seed(value: int) -> void:
	_effect_rng.seed = value


func get_enemy_count_for_section(section_id: int) -> int:
	var total := 0
	for runtime: StrategicGroupRuntime in _groups:
		if runtime.section_id == section_id:
			total += runtime.enemy_count
	return total


func retarget_fraction_from_section(section_id: int, ratio: float) -> int:
	if not _shield.is_valid_section(section_id) or ratio <= 0.0:
		return 0
	var candidates: Array[StrategicGroupRuntime] = []
	var total := 0
	for runtime: StrategicGroupRuntime in _groups:
		if runtime.section_id != section_id or runtime.enemy_count <= 0:
			continue
		candidates.append(runtime)
		total += runtime.enemy_count
	if total <= 0:
		return 0
	candidates.sort_custom(func(first: StrategicGroupRuntime, second: StrategicGroupRuntime) -> bool:
		return first.group_id < second.group_id
	)
	var requested := mini(total, maxi(1, int(round(float(total) * clampf(ratio, 0.0, 1.0)))))
	var retargeted := 0
	for runtime: StrategicGroupRuntime in candidates:
		if retargeted >= requested:
			break
		var move_count := mini(runtime.enemy_count, requested - retargeted)
		var target_section := _choose_alternative_section(section_id)
		if target_section < 0:
			break
		if move_count >= runtime.enemy_count:
			_retarget_whole_group(runtime, target_section)
			retargeted += move_count
			continue
		if get_available_group_slots() > 0:
			_split_group_for_retarget(runtime, move_count, target_section)
			retargeted += move_count
			continue
		var receiver := _find_retarget_receiver(runtime.group_id, section_id)
		if receiver == null:
			break
		_transfer_to_existing_group(runtime, receiver, move_count)
		retargeted += move_count
	strategic_enemies_retargeted.emit(section_id, retargeted)
	return retargeted


func destroy_nearest_rows(section_id: int, row_count: int) -> int:
	if not _shield.is_valid_section(section_id) or row_count <= 0:
		return 0
	var candidates: Array[StrategicGroupRuntime] = []
	for runtime: StrategicGroupRuntime in _groups:
		if runtime.section_id == section_id and runtime.enemy_count > 0:
			candidates.append(runtime)
	candidates.sort_custom(func(first: StrategicGroupRuntime, second: StrategicGroupRuntime) -> bool:
		if not is_equal_approx(first.map_distance, second.map_distance):
			return first.map_distance < second.map_distance
		return first.group_id < second.group_id
	)
	var destroyed := 0
	while destroyed < row_count and not candidates.is_empty():
		var runtime: StrategicGroupRuntime = candidates[0]
		runtime.enemy_count -= 1
		destroyed += 1
		if runtime.enemy_count <= 0:
			var index := _find_group_index(runtime.group_id)
			if index >= 0:
				_groups.remove_at(index)
				group_removed.emit(runtime.group_id)
			candidates.remove_at(0)
		else:
			group_changed.emit(runtime.group_id, runtime.enemy_count, runtime.progress)
	strategic_rows_destroyed.emit(section_id, destroyed)
	return destroyed


func _retarget_whole_group(runtime: StrategicGroupRuntime, target_section: int) -> void:
	runtime.replan_route(
		target_section,
		_shield.get_section_count(),
		_get_remaining_travel_duration(runtime),
		balance.mutation_cooldown
	)
	group_changed.emit(runtime.group_id, runtime.enemy_count, runtime.progress)


func _split_group_for_retarget(
	source: StrategicGroupRuntime,
	move_count: int,
	target_section: int
) -> void:
	var remaining_duration := _get_remaining_travel_duration(source)
	source.enemy_count -= move_count
	source.initial_enemy_count = maxi(source.enemy_count, source.initial_enemy_count - move_count)
	group_changed.emit(source.group_id, source.enemy_count, source.progress)
	var split := StrategicGroupRuntime.new(
		_next_group_id,
		target_section,
		move_count,
		remaining_duration,
		0.0,
		_shield.get_section_count(),
		balance.mutation_cooldown
	)
	_next_group_id += 1
	split.map_angle = source.map_angle
	split.map_distance = source.map_distance
	split.replan_route(
		target_section,
		_shield.get_section_count(),
		remaining_duration,
		balance.mutation_cooldown
	)
	_groups.append(split)
	group_added.emit(split.group_id, split.section_id, split.enemy_count)


func _find_retarget_receiver(
	source_group_id: int,
	source_section_id: int
) -> StrategicGroupRuntime:
	for runtime: StrategicGroupRuntime in _groups:
		if runtime.group_id == source_group_id:
			continue
		if runtime.section_id != source_section_id and runtime.enemy_count > 0:
			return runtime
	return null


func _transfer_to_existing_group(
	source: StrategicGroupRuntime,
	receiver: StrategicGroupRuntime,
	move_count: int
) -> void:
	source.enemy_count -= move_count
	source.initial_enemy_count = maxi(source.enemy_count, source.initial_enemy_count - move_count)
	receiver.enemy_count += move_count
	receiver.initial_enemy_count += move_count
	group_changed.emit(source.group_id, source.enemy_count, source.progress)
	group_changed.emit(receiver.group_id, receiver.enemy_count, receiver.progress)


func _choose_alternative_section(source_section_id: int) -> int:
	var section_count := _shield.get_section_count()
	if section_count <= 1:
		return -1
	var offset := _effect_rng.randi_range(1, section_count - 1)
	return (source_section_id + offset) % section_count
