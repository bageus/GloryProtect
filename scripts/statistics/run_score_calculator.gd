class_name RunScoreCalculator
extends RefCounted

const SCORE_FORMULA_VERSION: int = 1
const BONUS_INTERVAL_SECONDS: int = 300
const FIRST_INTERVAL_BONUS: float = 1000.0
const POINTS_PER_SECOND_OR_KILL: int = 10


static func calculate_score(
	survival_seconds: float,
	total_kills: int
) -> int:
	var full_seconds: int = get_full_survival_seconds(survival_seconds)
	var safe_kills: int = maxi(0, total_kills)
	var base_score: int = (
		full_seconds + safe_kills
	) * POINTS_PER_SECOND_OR_KILL
	return base_score + calculate_time_bonus(full_seconds)


static func calculate_time_bonus(full_survival_seconds: int) -> int:
	var interval_count: int = get_completed_bonus_intervals(
		full_survival_seconds
	)
	var harmonic_sum: float = 0.0
	for interval_index: int in range(1, interval_count + 1):
		harmonic_sum += 1.0 / float(interval_index)
	return roundi(FIRST_INTERVAL_BONUS * harmonic_sum)


static func get_full_survival_seconds(survival_seconds: float) -> int:
	return maxi(0, floori(maxf(0.0, survival_seconds)))


static func get_completed_bonus_intervals(
	full_survival_seconds: int
) -> int:
	return floori(
		float(maxi(0, full_survival_seconds))
		/ float(BONUS_INTERVAL_SECONDS)
	)
