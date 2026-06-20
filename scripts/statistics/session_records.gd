class_name SessionRecordsStore
extends Node

signal records_changed(
	completed_runs: int,
	best_survival_seconds: float,
	best_physical_kills: int
)

var _completed_runs: int = 0
var _best_survival_seconds: float = 0.0
var _best_physical_kills: int = 0


func register_result(snapshot: RunStatisticsSnapshot) -> void:
	_completed_runs += 1
	_best_survival_seconds = maxf(
		_best_survival_seconds,
		snapshot.survival_seconds
	)
	_best_physical_kills = maxi(
		_best_physical_kills,
		snapshot.physical_kills
	)
	records_changed.emit(
		_completed_runs,
		_best_survival_seconds,
		_best_physical_kills
	)


func get_completed_runs() -> int:
	return _completed_runs


func get_best_survival_seconds() -> float:
	return _best_survival_seconds


func get_best_physical_kills() -> int:
	return _best_physical_kills


func reset_records() -> void:
	_completed_runs = 0
	_best_survival_seconds = 0.0
	_best_physical_kills = 0
	records_changed.emit(0, 0.0, 0)
