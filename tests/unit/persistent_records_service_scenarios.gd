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
	assert(service.register_result(_snapshot(125.0, 12)) == OK)
	assert(service.register_result(_snapshot(80.0, 4)) == OK)
	assert(service.get_completed_runs() == 2)
	assert(is_equal_approx(service.get_best_survival_seconds(), 125.0))
	assert(service.get_best_physical_kills() == 12)

	var reloaded := PersistentRecordsService.new()
	reloaded.set_records_path_for_tests(TEST_PATH)
	root.add_child(reloaded)
	await process_frame
	assert(reloaded.get_format_version() == 1)
	assert(reloaded.get_completed_runs() == 2)
	assert(is_equal_approx(reloaded.get_best_survival_seconds(), 125.0))
	assert(reloaded.get_best_physical_kills() == 12)

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

	assert(corrupted.register_result(_snapshot(42.0, 3)) == OK)
	var recovered := PersistentRecordsService.new()
	recovered.set_records_path_for_tests(TEST_PATH)
	root.add_child(recovered)
	await process_frame
	assert(recovered.get_completed_runs() == 1)
	assert(is_equal_approx(recovered.get_best_survival_seconds(), 42.0))
	assert(recovered.get_best_physical_kills() == 3)

	service.queue_free()
	reloaded.queue_free()
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
