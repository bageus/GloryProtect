class_name SteeringInputProvider
extends Node

signal driver_availability_changed(is_available: bool)

@export var left_action: StringName = &"gp_move_left"
@export var right_action: StringName = &"gp_move_right"
@export var driver_available: bool = true


func get_steering_axis() -> float:
	if not driver_available:
		return 0.0
	var configured_axis: float = Input.get_axis(left_action, right_action)
	if not is_zero_approx(configured_axis):
		return configured_axis
	return Input.get_axis(&"ui_left", &"ui_right")


func is_control_input_active() -> bool:
	if not driver_available:
		return false
	return (
		Input.is_action_pressed(left_action)
		or Input.is_action_pressed(right_action)
		or Input.is_action_pressed(&"ui_left")
		or Input.is_action_pressed(&"ui_right")
	)


func set_driver_available(value: bool) -> void:
	if driver_available == value:
		return
	driver_available = value
	driver_availability_changed.emit(driver_available)
