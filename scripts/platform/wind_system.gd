class_name WindSystem
extends Node

signal wind_state_changed(direction: int, strength_level: int, base_force: float)

@export var balance: WindBalance

var direction: int = 1
var strength_level: int = 1
var elapsed_time: float = 0.0
var _state_time: float = 0.0
var _next_change_time: float = 6.0
var _influence_reduction_ratio: float = 0.0
var _ignore_strength_one: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	assert(balance != null, "WindSystem requires WindBalance")
	_rng.randomize()
	_schedule_next_change()
	wind_state_changed.emit(direction, strength_level, get_base_force())


func _physics_process(delta: float) -> void:
	elapsed_time += delta
	_state_time += delta
	if _state_time >= _next_change_time:
		_roll_next_state()


func get_base_force() -> float:
	if balance == null or balance.level_forces.is_empty():
		return 0.0
	var index := clampi(strength_level - 1, 0, balance.level_forces.size() - 1)
	return balance.level_forces[index]


func get_current_force() -> float:
	if balance == null:
		return 0.0
	if _ignore_strength_one and strength_level == 1:
		return 0.0
	var wobble := sin(elapsed_time * balance.fluctuation_speed) * balance.fluctuation_force
	var raw_force: float = maxf(0.0, get_base_force() + wobble)
	return float(direction) * raw_force * get_influence_multiplier()


func set_anchorless_modifiers(
	influence_reduction_ratio: float,
	ignore_strength_one: bool
) -> void:
	_influence_reduction_ratio = clampf(influence_reduction_ratio, 0.0, 1.0)
	_ignore_strength_one = ignore_strength_one


func reset_anchorless_modifiers() -> void:
	set_anchorless_modifiers(0.0, false)


func get_influence_multiplier() -> float:
	return maxf(0.0, 1.0 - _influence_reduction_ratio)


func is_strength_one_ignored() -> bool:
	return _ignore_strength_one


func get_direction_text() -> String:
	return "ВПРАВО" if direction > 0 else "ВЛЕВО"


func set_debug_state(new_direction: int, new_strength_level: int) -> void:
	direction = 1 if new_direction >= 0 else -1
	strength_level = clampi(new_strength_level, 1, _get_max_strength_level())
	_state_time = 0.0
	_schedule_next_change()
	wind_state_changed.emit(direction, strength_level, get_base_force())


func _roll_next_state() -> void:
	_state_time = 0.0
	direction = -1 if _rng.randf() < 0.5 else 1
	strength_level = _rng.randi_range(1, _get_max_strength_level())
	_schedule_next_change()
	wind_state_changed.emit(direction, strength_level, get_base_force())


func _schedule_next_change() -> void:
	if balance == null:
		_next_change_time = 1.0
		return
	var low := minf(balance.change_interval_min, balance.change_interval_max)
	var high := maxf(balance.change_interval_min, balance.change_interval_max)
	_next_change_time = _rng.randf_range(low, high)


func _get_max_strength_level() -> int:
	if balance == null:
		return 1
	return maxi(1, balance.level_forces.size())
