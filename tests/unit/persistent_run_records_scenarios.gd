extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var records := PersistentRunRecords.new()
	assert(records.completed_runs == 0)
	assert(is_zero_approx(records.best_survival_seconds))
	assert(records.best_physical_kills == 0)

	assert(records.register_result(_snapshot(120.0, 10)))
	assert(records.register_result(_snapshot(60.0, 5)))
	assert(records.completed_runs == 2)
	assert(is_equal_approx(records.best_survival_seconds, 120.0))
	assert(records.best_physical_kills == 10)

	assert(records.register_result(_snapshot(180.0, 8)))
	assert(records.register_result(_snapshot(90.0, 20)))
	assert(records.completed_runs == 4)
	assert(is_equal_approx(records.best_survival_seconds, 180.0))
	assert(records.best_physical_kills == 20)

	var encoded: Dictionary = records.to_dictionary()
	assert(int(encoded["format_version"]) == 1)
	var restored := PersistentRunRecords.from_dictionary(encoded)
	assert(restored.format_version == PersistentRunRecords.CURRENT_FORMAT_VERSION)
	assert(restored.completed_runs == 4)
	assert(is_equal_approx(restored.best_survival_seconds, 180.0))
	assert(restored.best_physical_kills == 20)

	var migrated := PersistentRunRecords.from_dictionary({
		"completed_runs": 7,
		"best_time_seconds": 245.5,
		"best_kills": 31,
	})
	assert(migrated.format_version == PersistentRunRecords.CURRENT_FORMAT_VERSION)
	assert(migrated.completed_runs == 7)
	assert(is_equal_approx(migrated.best_survival_seconds, 245.5))
	assert(migrated.best_physical_kills == 31)

	var future := PersistentRunRecords.from_dictionary({
		"format_version": 999,
		"completed_runs": 99,
		"best_survival_seconds": 999.0,
		"best_physical_kills": 99,
	})
	assert(future.completed_runs == 0)
	assert(is_zero_approx(future.best_survival_seconds))
	assert(future.best_physical_kills == 0)

	var malformed := PersistentRunRecords.from_dictionary({
		"format_version": 1,
		"completed_runs": "many",
		"best_survival_seconds": -10.0,
		"best_physical_kills": -4,
	})
	assert(malformed.completed_runs == 0)
	assert(is_zero_approx(malformed.best_survival_seconds))
	assert(malformed.best_physical_kills == 0)

	print("Persistent run records scenarios passed")
	quit()


func _snapshot(seconds: float, kills: int) -> RunStatisticsSnapshot:
	return RunStatisticsSnapshot.new(seconds, kills, 0, 0, &"test_end")
