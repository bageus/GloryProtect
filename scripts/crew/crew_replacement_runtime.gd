class_name CrewReplacementRuntime
extends RefCounted

var defender_id: int
var remaining_seconds: float


func _init(new_defender_id: int, duration_seconds: float) -> void:
	defender_id = new_defender_id
	remaining_seconds = maxf(0.0, duration_seconds)


func tick(delta: float) -> bool:
	remaining_seconds = maxf(0.0, remaining_seconds - delta)
	return is_complete()


func is_complete() -> bool:
	return remaining_seconds <= 0.0
