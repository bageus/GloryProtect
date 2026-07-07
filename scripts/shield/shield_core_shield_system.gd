class_name ShieldCoreShieldSystem
extends ShieldSystem

signal emergency_reserve_triggered(section_id: int)
signal emergency_hold_ended(section_id: int)

var _capacity_multiplier: float = 1.0
var _reserve_enabled: bool = false
var _reserve_used: bool = false
var _reserve_floor_percent: float = 1.0
var _reserve_hold_seconds: float = 5.0
var _reserve_holds := PackedFloat32Array()


func set_capacity_multiplier(value: float) -> void:
	var next_multiplier := maxf(1.0, value)
	if is_equal_approx(_capacity_multiplier, next_multiplier):
		return
	_capacity_multiplier = next_multiplier
	var next_max := get_effective_max_health()
	for section_id: int in range(get_section_count()):
		_health[section_id] = clampf(_health[section_id], 0.0, next_max)
		_update_critical_state(section_id)
		section_changed.emit(section_id, _health[section_id], next_max, get_display_health_percent(section_id))


func get_capacity_multiplier() -> float:
	return _capacity_multiplier


func get_effective_max_health() -> float:
	return balance.max_health * _capacity_multiplier


func get_max_health() -> float:
	return get_effective_max_health()


func configure_emergency_reserve(enabled: bool, floor_percent: float, hold_seconds: float) -> void:
	_reserve_floor_percent = clampf(floor_percent, 0.1, 100.0)
	_reserve_hold_seconds = maxf(0.0, hold_seconds)
	if _reserve_enabled == enabled:
		return
	_reserve_enabled = enabled
	if not enabled:
		_reserve_used = false
		for section_id: int in range(_reserve_holds.size()):
			_reserve_holds[section_id] = 0.0


func has_emergency_reserve_been_used() -> bool:
	return _reserve_used


func is_section_held(section_id: int) -> bool:
	return is_valid_section(section_id) and _reserve_holds[section_id] > 0.0


func tick_emergency_reserve(delta: float) -> void:
	for section_id: int in range(_reserve_holds.size()):
		var previous := _reserve_holds[section_id]
		if previous <= 0.0:
			continue
		_reserve_holds[section_id] = maxf(0.0, previous - maxf(0.0, delta))
		if is_zero_approx(_reserve_holds[section_id]):
			emergency_hold_ended.emit(section_id)


func apply_damage(section_id: int, amount: float) -> void:
	if amount <= 0.0 or not is_valid_section(section_id) or is_section_held(section_id):
		return
	var next_health := _health[section_id] - amount
	if _reserve_enabled and not _reserve_used and next_health <= 0.0:
		_reserve_used = true
		_reserve_holds[section_id] = _reserve_hold_seconds
		set_health(section_id, get_effective_max_health() * _reserve_floor_percent / 100.0)
		emergency_reserve_triggered.emit(section_id)
		return
	set_health(section_id, next_health)


func restore(section_id: int, amount: float) -> void:
	if amount <= 0.0 or not is_valid_section(section_id) or is_section_held(section_id):
		return
	set_health(section_id, _health[section_id] + amount)


func set_health(section_id: int, value: float) -> void:
	if not is_valid_section(section_id):
		return
	var previous_health := _health[section_id]
	var next_health := clampf(value, 0.0, get_effective_max_health())
	if is_equal_approx(previous_health, next_health):
		return
	_health[section_id] = next_health
	_update_critical_state(section_id)
	section_changed.emit(section_id, next_health, get_effective_max_health(), get_display_health_percent(section_id))
	if previous_health > 0.0 and is_zero_approx(next_health):
		section_destroyed.emit(section_id)


func get_health_percent(section_id: int) -> float:
	if not is_valid_section(section_id):
		return 0.0
	return _health[section_id] / get_effective_max_health() * 100.0


func get_weakest_damaged_section(excluded_section_id: int = -1) -> int:
	var best_id := -1
	var best_percent := INF
	for section_id: int in range(get_section_count()):
		if section_id == excluded_section_id:
			continue
		var percent := get_display_health_percent(section_id)
		if percent < 100.0 and percent < best_percent:
			best_percent = percent
			best_id = section_id
	return best_id


func get_nearest_damaged_section(origin_section_id: int) -> int:
	var best_id := -1
	var best_distance := 999999
	for section_id: int in range(get_section_count()):
		if section_id == origin_section_id or get_display_health_percent(section_id) >= 100.0:
			continue
		var distance := absi(section_id - origin_section_id)
		if distance < best_distance:
			best_distance = distance
			best_id = section_id
	return best_id


func _initialize_sections() -> void:
	_health = PackedFloat32Array()
	_critical_states.clear()
	_reserve_holds = PackedFloat32Array()
	_health.resize(balance.section_count)
	_reserve_holds.resize(balance.section_count)
	var maximum := get_effective_max_health()
	for section_id: int in range(balance.section_count):
		_health[section_id] = maximum
		_reserve_holds[section_id] = 0.0
		_critical_states.append(false)
		section_changed.emit(section_id, maximum, maximum, 100.0)
