extends SceneTree

const TEST_PATH := "user://persistent_records_service_scenarios.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_file()
	var service := PersistentRecordsService.new()
	service.set_records_path_for_tests(TEST_PATH)
	root.add_child(service)
	await process_frame
	assert(service.get_completed_runs() == 0)
	assert(service.get_best_score() == 0)
	assert(service.register_result(_snapshot(125.0, 12)) == OK)
	assert(service.is_latest_score_record())
	assert(service.register_result(_snapshot(80.0, 4)) == OK)
	assert(not service.is_latest_score_record())
	assert(service.get_completed_runs() == 2)
	assert(is_equal_approx(service.get_best_survival_seconds(), 125.0))
	assert(service.get_best_physical_kills() == 12)
	assert(service.get_best_score() == 1370)

	var reloaded := PersistentRecordsService.new()
	reloaded.set_records_path_for_tests(TEST_PATH)
	root.add_child(reloaded)
	await process_frame
	assert(reloaded.get_format_version() == 2)
	assert(reloaded.get_score_formula_version() == 1)
	assert(reloaded.get_completed_runs() == 2)
	assert(is_equal_approx(reloaded.get_best_survival_seconds(), 125.0))
	assert(reloaded.get_best_physical_kills() == 12)
	assert(reloaded.get_best_score() == 1370)
	assert(not reloaded.is_latest_score_record())

	var version_one_file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	assert(version_one_file != null)
	version_one_file.store_string(JSON.stringify({
		"format_version": 1,
		"completed_runs": 9,
		"best_survival_seconds": 250.0,
		"best_physical_kills": 25,
	}))
	version_one_file = null
	var migrated := PersistentRecordsService.new()
	migrated.set_records_path_for_tests(TEST_PATH)
	root.add_child(migrated)
	await process_frame
	assert(migrated.get_format_version() == 2)
	assert(migrated.get_score_formula_version() == 1)
	assert(migrated.get_completed_runs() == 9)
	assert(is_equal_approx(migrated.get_best_survival_seconds(), 250.0))
	assert(migrated.get_best_physical_kills() == 25)
	assert(migrated.get_best_score() == 0)
	var migrated_file := FileAccess.open(TEST_PATH, FileAccess.READ)
	assert(migrated_file != null)
	var migrated_data: Variant = JSON.parse_string(migrated_file.get_as_text())
	assert(migrated_data is Dictionary)
	assert(int((migrated_data as Dictionary)["format_version"]) == 2)
	assert(int((migrated_data as Dictionary)["score_formula_version"]) == 1)

	var corrupt_file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	assert(corrupt_file != null)
	corrupt_file.store_string("{broken json")
	corrupt_file = null

	var corrupted := PersistentRecordsService.new()
	corrupted.set_records_path_for_tests(TEST_PATH)
	root.add_child(corrupted)
	await process_frame
	assert(corrupted.load_records() == ERR_PARSE_ERROR)
	assert(corrupted.get_completed_runs() == 0)
	assert(is_zero_approx(corrupted.get_best_survival_seconds()))
	assert(corrupted.get_best_physical_kills() == 0)
	assert(corrupted.get_best_score() == 0)

	assert(corrupted.register_result(_snapshot(42.0, 3)) == OK)
	assert(corrupted.is_latest_score_record())
	var recovered := PersistentRecordsService.new()
	recovered.set_records_path_for_tests(TEST_PATH)
	root.add_child(recovered)
	await process_frame
	assert(recovered.get_completed_runs() == 1)
	assert(is_equal_approx(recovered.get_best_survival_seconds(), 42.0))
	assert(recovered.get_best_physical_kills() == 3)
	assert(recovered.get_best_score() == 450)

	service.queue_free()
	reloaded.queue_free()
	migrated.queue_free()
	corrupted.queue_free()
	recovered.queue_free()
	_remove_test_file()
	print("Persistent records service scenarios passed")
	quit()


func _snapshot(seconds: float, kills: int) -> RunStatisticsSnapshot:
	return RunStatisticsSnapshot.new(seconds, kills, 0, 0, &"test_end")


func _remove_test_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
