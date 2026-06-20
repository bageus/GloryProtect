class_name StrategicWaveBalance
extends Resource

@export_range(0.0, 60.0, 0.5) var first_wave_delay: float = 5.0
@export_range(0.5, 60.0, 0.5) var initial_wave_interval: float = 12.0
@export_range(0.5, 60.0, 0.5) var minimum_wave_interval: float = 4.0
@export_range(1, 500, 1) var initial_wave_size: int = 6
@export_range(1, 1000, 1) var maximum_wave_size: int = 30
@export_range(0.5, 60.0, 0.5) var initial_travel_duration: float = 8.0
@export_range(0.5, 60.0, 0.5) var minimum_travel_duration: float = 4.0
@export_range(1, 5, 1) var initial_target_sections: int = 1
@export_range(1, 5, 1) var maximum_target_sections: int = 3
@export_range(0.01, 5.0, 0.01) var impact_interval: float = 0.35
@export_range(0.1, 100.0, 0.1) var damage_per_enemy: float = 1.0
@export_range(1, 100, 1) var max_active_groups: int = 15
@export_range(0.0, 1.2, 0.05) var maximum_lane_offset: float = 0.35


func get_wave_interval(normalized_difficulty: float) -> float:
	return _lerp_decreasing(
		initial_wave_interval,
		minimum_wave_interval,
		normalized_difficulty
	)


func get_wave_size(normalized_difficulty: float) -> int:
	var progress: float = clampf(normalized_difficulty, 0.0, 1.0)
	var final_size: int = maxi(initial_wave_size, maximum_wave_size)
	return roundi(lerpf(float(initial_wave_size), float(final_size), progress))


func get_travel_duration(normalized_difficulty: float) -> float:
	return _lerp_decreasing(
		initial_travel_duration,
		minimum_travel_duration,
		normalized_difficulty
	)


func get_target_section_count(
	normalized_difficulty: float,
	available_section_count: int
) -> int:
	if available_section_count <= 0:
		return 0
	var progress: float = clampf(normalized_difficulty, 0.0, 1.0)
	var initial_count: int = clampi(
		initial_target_sections,
		1,
		available_section_count
	)
	var maximum_count: int = clampi(
		maxi(initial_count, maximum_target_sections),
		1,
		available_section_count
	)
	return roundi(lerpf(float(initial_count), float(maximum_count), progress))


func _lerp_decreasing(start_value: float, end_value: float, progress: float) -> float:
	var safe_progress: float = clampf(progress, 0.0, 1.0)
	var final_value: float = minf(start_value, end_value)
	return lerpf(start_value, final_value, safe_progress)
