class_name PersistentRecordsService
extends Node

signal records_changed

const RECORDS_PATH := "user://run_records.json"

var _records_path: String = RECORDS_PATH
var _records: PersistentRunRecords = PersistentRunRecords.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_records()


func register_result(snapshot: RunStatisticsSnapshot) -> Error:
	if not _records.register_result(snapshot):
		return ERR_INVALID_PARAMETER
	var save_error: Error = save_records()
	records_changed.emit()
	return save_error


func get_format_version() -> int:
	return _records.format_version


func get_completed_runs() -> int:
	return _records.completed_runs


func get_best_survival_seconds() -> float:
	return _records.best_survival_seconds


func get_best_physical_kills() -> int:
	return _records.best_physical_kills


func save_records() -> Error:
	var file := FileAccess.open(_records_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(_records.to_dictionary(), "\t"))
	return OK


func load_records() -> Error:
	_records = PersistentRunRecords.new()
	if not FileAccess.file_exists(_records_path):
		records_changed.emit()
		return OK
	var file := FileAccess.open(_records_path, FileAccess.READ)
	if file == null:
		records_changed.emit()
		return FileAccess.get_open_error()
	var parser := JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	if parse_error != OK or not (parser.data is Dictionary):
		records_changed.emit()
		return ERR_PARSE_ERROR
	_records = PersistentRunRecords.from_dictionary(parser.data)
	records_changed.emit()
	return OK


func set_records_path_for_tests(path: String) -> void:
	_records_path = path


func reset_records_for_tests(remove_file: bool = false) -> void:
	_records = PersistentRunRecords.new()
	if remove_file and FileAccess.file_exists(_records_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_records_path))
	records_changed.emit()
