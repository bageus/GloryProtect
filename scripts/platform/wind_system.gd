class_name WindSystem
extends Node

signal wind_state_changed(direction: int, strength_level: int, base_force: float)

@export var level_forces: PackedFloat32Array = PackedFloat32Array([42.0, 78.0, 126.0])
@export_range(1.0, 30.0, 0.1) var change_interval_min: float = 5.0
@export_range(1.0, 30.0, 0.1) var change_interval_max: float = 9.0
@export_range(0.0, 50.0, 0.1) var fluctuation_force: float = 8.0
@export_range(0.1, 5.0, 0.1) var fluctuation_speed: float = 0.85

var direction: int = 1
var strength_level: int = 1
var elapsed_time: float = 0.0
var _state_time: float = 0.0
var _next_change_time: float = 6.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_schedule_next_change()
	wind_state_changed.emit(direction, strength_level, get_base_force())


func _physics_process(delta: float) -> void:
	elapsed_time += delta
	_state_time += delta
	if _state_time >= _next_change_time:
		_roll_next_state()


func get_base_force() -> float:
	if level_forces.is_empty():
		return 0.0
	var index := clampi(strength_level - 1, 0, level_forces.size() - 1)
	return level_forces[index]


func get_current_force() -> float:
	var wobble := sin(elapsed_time * fluctuation_speed) * fluctuation_force
	return float(direction) * maxf(0.0, get_base_force() + wobble)


func get_direction_text() -> String:
	return "ВПРАВО" if direction > 0 else "ВЛЕВО"


func set_debug_state(new_direction: int, new_strength_level: int) -> void:
	direction = 1 if new_direction >= 0 else -1
	strength_level = clampi(new_strength_level, 1, max(1, level_forces.size()))
	_state_time = 0.0
	_schedule_next_change()
	wind_state_changed.emit(direction, strength_level, get_base_force())


func _roll_next_state() -> void:
	_state_time = 0.0

	# Direction and strength are independent. This intentionally allows the
	# same state to repeat so the wind does not feel mechanically alternating.
	direction = -1 if _rng.randf() < 0.5 else 1
	strength_level = _rng.randi_range(1, max(1, level_forces.size()))
	_schedule_next_change()
	wind_state_changed.emit(direction, strength_level, get_base_force())


func _schedule_next_change() -> void:
	var low := minf(change_interval_min, change_interval_max)
	var high := maxf(change_interval_min, change_interval_max)
	_next_change_time = _rng.randf_range(low, high)
