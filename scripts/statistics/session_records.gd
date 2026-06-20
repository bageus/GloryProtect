class_name SessionRecordsStore
extends RefCounted

static var _completed_runs: int = 0
static var _best_survival_seconds: float = 0.0
static var _best_physical_kills: int = 0


static func register_result(snapshot: RunStatisticsSnapshot) -> void:
	_completed_runs += 1
	_best_survival_seconds = maxf(
		_best_survival_seconds,
		snapshot.survival_seconds
	)
	_best_physical_kills = maxi(
		_best_physical_kills,
		snapshot.physical_kills
	)


static func get_completed_runs() -> int:
	return _completed_runs


static func get_best_survival_seconds() -> float:
	return _best_survival_seconds


static func get_best_physical_kills() -> int:
	return _best_physical_kills


static func reset_records() -> void:
	_completed_runs = 0
	_best_survival_seconds = 0.0
	_best_physical_kills = 0
