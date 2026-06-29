class_name PersistentRecords
extends RefCounted


static func register_result(snapshot: RunStatisticsSnapshot) -> Error:
	return _service().register_result(snapshot)


static func get_format_version() -> int:
	return _service().get_format_version()


static func get_completed_runs() -> int:
	return _service().get_completed_runs()


static func get_best_survival_seconds() -> float:
	return _service().get_best_survival_seconds()


static func get_best_physical_kills() -> int:
	return _service().get_best_physical_kills()


static func _service() -> PersistentRecordsService:
	var tree := Engine.get_main_loop() as SceneTree
	assert(tree != null, "PersistentRecords requires an active SceneTree")
	var service := tree.root.get_node_or_null(
		"PersistentRecordsRuntime"
	) as PersistentRecordsService
	assert(service != null, "PersistentRecordsRuntime autoload is missing")
	return service
