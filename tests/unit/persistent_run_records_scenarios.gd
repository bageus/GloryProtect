extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var records := PersistentRunRecords.new()
	assert(records.format_version == 2)
	assert(records.score_formula_version == 1)
	assert(records.completed_runs == 0)
	assert(is_zero_approx(records.best_survival_seconds))
	assert(records.best_physical_kills == 0)
	assert(records.best_score == 0)

	assert(records.register_result(_snapshot(120.0, 10)))
	assert(records.latest_score_is_record)
	assert(records.best_score == 1300)
	assert(records.register_result(_snapshot(60.0, 5)))
	assert(not records.latest_score_is_record)
	assert(records.completed_runs == 2)
	assert(is_equal_approx(records.best_survival_seconds, 120.0))
	assert(records.best_physical_kills == 10)
	assert(records.best_score == 1300)

	assert(records.register_result(_snapshot(130.0, 0)))
	assert(records.latest_score_is_record)
	assert(records.best_score == 1300)

	assert(records.register_result(_snapshot(180.0, 8)))
	assert(records.latest_score_is_record)
	assert(records.register_result(_snapshot(90.0, 20)))
	assert(records.latest_score_is_record)
	assert(records.completed_runs == 5)
	assert(is_equal_approx(records.best_survival_seconds, 180.0))
	assert(records.best_physical_kills == 20)
	assert(records.best_score == 1100)

	var encoded: Dictionary = records.to_dictionary()
	assert(int(encoded["format_version"]) == 2)
	assert(int(encoded["score_formula_version"]) == 1)
	var restored := PersistentRunRecords.from_dictionary(encoded)
	assert(restored.format_version == PersistentRunRecords.CURRENT_FORMAT_VERSION)
	assert(restored.score_formula_version == 1)
	assert(restored.completed_runs == 5)
	assert(is_equal_approx(restored.best_survival_seconds, 180.0))
	assert(restored.best_physical_kills == 20)
	assert(restored.best_score == 1100)
	assert(not restored.latest_score_is_record)

	var migrated_v1 := PersistentRunRecords.from_dictionary({
		"format_version": 1,
		"completed_runs": 7,
		"best_survival_seconds": 245.5,
		"best_physical_kills": 31,
	})
	assert(migrated_v1.format_version == 2)
	assert(migrated_v1.score_formula_version == 1)
	assert(migrated_v1.completed_runs == 7)
	assert(is_equal_approx(migrated_v1.best_survival_seconds, 245.5))
	assert(migrated_v1.best_physical_kills == 31)
	assert(migrated_v1.best_score == 0)

	var migrated_legacy := PersistentRunRecords.from_dictionary({
		"completed_runs": 6,
		"best_time_seconds": 210.5,
		"best_kills": 28,
	})
	assert(migrated_legacy.format_version == 2)
	assert(migrated_legacy.completed_runs == 6)
	assert(is_equal_approx(migrated_legacy.best_survival_seconds, 210.5))
	assert(migrated_legacy.best_physical_kills == 28)
	assert(migrated_legacy.best_score == 0)

	var changed_formula := PersistentRunRecords.from_dictionary({
		"format_version": 2,
		"score_formula_version": 999,
		"completed_runs": 9,
		"best_survival_seconds": 300.0,
		"best_physical_kills": 40,
		"best_score": 999999,
	})
	assert(changed_formula.completed_runs == 9)
	assert(is_equal_approx(changed_formula.best_survival_seconds, 300.0))
	assert(changed_formula.best_physical_kills == 40)
	assert(changed_formula.best_score == 0)
	assert(changed_formula.score_formula_version == 1)

	var future := PersistentRunRecords.from_dictionary({
		"format_version": 999,
		"completed_runs": 99,
		"best_survival_seconds": 999.0,
		"best_physical_kills": 99,
		"best_score": 999,
	})
	assert(future.completed_runs == 0)
	assert(is_zero_approx(future.best_survival_seconds))
	assert(future.best_physical_kills == 0)
	assert(future.best_score == 0)

	var malformed := PersistentRunRecords.from_dictionary({
		"format_version": 2,
		"score_formula_version": 1,
		"completed_runs": "many",
		"best_survival_seconds": -10.0,
		"best_physical_kills": -4,
		"best_score": -100,
	})
	assert(malformed.completed_runs == 0)
	assert(is_zero_approx(malformed.best_survival_seconds))
	assert(malformed.best_physical_kills == 0)
	assert(malformed.best_score == 0)

	print("Persistent run records scenarios passed")
	quit()


func _snapshot(seconds: float, kills: int) -> RunStatisticsSnapshot:
	return RunStatisticsSnapshot.new(seconds, kills, 0, 0, &"test_end")
