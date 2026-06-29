extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(RunScoreCalculator.get_full_survival_seconds(-1.0) == 0)
	assert(RunScoreCalculator.get_full_survival_seconds(12.99) == 12)
	assert(RunScoreCalculator.get_completed_bonus_intervals(299) == 0)
	assert(RunScoreCalculator.get_completed_bonus_intervals(300) == 1)
	assert(RunScoreCalculator.get_completed_bonus_intervals(600) == 2)

	assert(RunScoreCalculator.calculate_time_bonus(299) == 0)
	assert(RunScoreCalculator.calculate_time_bonus(300) == 1000)
	assert(RunScoreCalculator.calculate_time_bonus(600) == 1500)
	assert(RunScoreCalculator.calculate_time_bonus(900) == 1833)
	assert(RunScoreCalculator.calculate_time_bonus(1200) == 2083)
	assert(RunScoreCalculator.calculate_time_bonus(1500) == 2283)

	assert(RunScoreCalculator.calculate_score(0.0, 0) == 0)
	assert(RunScoreCalculator.calculate_score(12.99, 3) == 150)
	assert(RunScoreCalculator.calculate_score(299.9, 1) == 3000)
	assert(RunScoreCalculator.calculate_score(300.0, 0) == 4000)
	assert(RunScoreCalculator.calculate_score(600.0, 10) == 7600)
	assert(RunScoreCalculator.calculate_score(-5.0, -2) == 0)

	print("Run score calculator scenarios passed")
	quit()
