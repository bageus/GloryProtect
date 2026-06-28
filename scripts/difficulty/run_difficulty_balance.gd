class_name RunDifficultyBalance
extends Resource

@export_range(1.0, 7200.0, 1.0) var seconds_to_max_difficulty: float = 720.0
@export_range(0.1, 4.0, 0.05) var growth_exponent: float = 1.0
@export_range(30.0, 1200.0, 1.0) var overtime_step_seconds: float = 120.0
@export_range(0, 20, 1) var maximum_overtime_tier: int = 6


func get_normalized_for_elapsed(elapsed_seconds: float) -> float:
	var linear_progress: float = clampf(
		maxf(0.0, elapsed_seconds) / maxf(1.0, seconds_to_max_difficulty),
		0.0,
		1.0
	)
	return pow(linear_progress, growth_exponent)


func get_overtime_tier_for_elapsed(elapsed_seconds: float) -> int:
	if elapsed_seconds < seconds_to_max_difficulty:
		return 0
	var overtime_seconds: float = elapsed_seconds - seconds_to_max_difficulty
	var tier: int = floori(overtime_seconds / maxf(1.0, overtime_step_seconds)) + 1
	return clampi(tier, 0, maximum_overtime_tier)
