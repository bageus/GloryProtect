class_name RunDifficultyBalance
extends Resource

@export_range(1.0, 7200.0, 1.0) var seconds_to_max_difficulty: float = 600.0
@export_range(0.1, 4.0, 0.05) var growth_exponent: float = 1.0


func get_normalized_for_elapsed(elapsed_seconds: float) -> float:
	var linear_progress: float = clampf(
		maxf(0.0, elapsed_seconds) / maxf(1.0, seconds_to_max_difficulty),
		0.0,
		1.0
	)
	return pow(linear_progress, growth_exponent)
