class_name PersistentRunRecords
extends RefCounted

const CURRENT_FORMAT_VERSION: int = 1

var format_version: int = CURRENT_FORMAT_VERSION
var completed_runs: int = 0
var best_survival_seconds: float = 0.0
var best_physical_kills: int = 0


func register_result(snapshot: RunStatisticsSnapshot) -> bool:
	if snapshot == null:
		return false
	completed_runs += 1
	best_survival_seconds = maxf(
		best_survival_seconds,
		snapshot.survival_seconds
	)
	best_physical_kills = maxi(
		best_physical_kills,
		snapshot.physical_kills
	)
	return true


func to_dictionary() -> Dictionary:
	return {
		"format_version": CURRENT_FORMAT_VERSION,
		"completed_runs": completed_runs,
		"best_survival_seconds": best_survival_seconds,
		"best_physical_kills": best_physical_kills,
	}


static func from_dictionary(raw_data: Variant) -> PersistentRunRecords:
	var records := PersistentRunRecords.new()
	if not (raw_data is Dictionary):
		return records
	var data: Dictionary = raw_data
	var version: int = _read_format_version(data)
	match version:
		0:
			_load_legacy_data(records, data)
		CURRENT_FORMAT_VERSION:
			_load_current_data(records, data)
		_:
			return records
	records.format_version = CURRENT_FORMAT_VERSION
	return records


static func _read_format_version(data: Dictionary) -> int:
	if data.has("format_version"):
		return _read_non_negative_int(data, "format_version")
	if data.has("version"):
		return _read_non_negative_int(data, "version")
	return 0


static func _load_current_data(
	records: PersistentRunRecords,
	data: Dictionary
) -> void:
	records.completed_runs = _read_non_negative_int(data, "completed_runs")
	records.best_survival_seconds = _read_non_negative_float(
		data,
		"best_survival_seconds"
	)
	records.best_physical_kills = _read_non_negative_int(
		data,
		"best_physical_kills"
	)


static func _load_legacy_data(
	records: PersistentRunRecords,
	data: Dictionary
) -> void:
	records.completed_runs = _read_non_negative_int(data, "completed_runs")
	if data.has("best_survival_seconds"):
		records.best_survival_seconds = _read_non_negative_float(
			data,
			"best_survival_seconds"
		)
	else:
		records.best_survival_seconds = _read_non_negative_float(
			data,
			"best_time_seconds"
		)
	if data.has("best_physical_kills"):
		records.best_physical_kills = _read_non_negative_int(
			data,
			"best_physical_kills"
		)
	else:
		records.best_physical_kills = _read_non_negative_int(
			data,
			"best_kills"
		)


static func _read_non_negative_int(data: Dictionary, key: String) -> int:
	var raw_value: Variant = data.get(key, 0)
	if typeof(raw_value) not in [TYPE_INT, TYPE_FLOAT]:
		return 0
	return maxi(0, int(raw_value))


static func _read_non_negative_float(data: Dictionary, key: String) -> float:
	var raw_value: Variant = data.get(key, 0.0)
	if typeof(raw_value) not in [TYPE_INT, TYPE_FLOAT]:
		return 0.0
	return maxf(0.0, float(raw_value))
