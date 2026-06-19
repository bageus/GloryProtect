class_name BoardingJumpPlan
extends RefCounted

var start_x: float
var landing_x: float
var duration: float
var height: float


func _init(
	new_start_x: float,
	new_landing_x: float,
	new_duration: float,
	new_height: float
) -> void:
	start_x = new_start_x
	landing_x = new_landing_x
	duration = maxf(0.01, new_duration)
	height = maxf(0.0, new_height)


func get_direction() -> float:
	return signf(landing_x - start_x)
