class_name ShieldSystem
extends Node

signal section_changed(
	section_id: int,
	current_health: float,
	max_health: float,
	percent: float
)
signal section_entered_critical(section_id: int)
signal section_left_critical(section_id: int)
signal section_destroyed(section_id: int)

@export var balance: ShieldBalance

var _health := PackedFloat32Array()
var _critical_states: Array[bool] = []


func _ready() -> void:
	assert(balance != null, "ShieldSystem requires ShieldBalance")
	_initialize_sections()


func reset_all() -> void:
	_initialize_sections()


func get_section_count() -> int:
	return _health.size()


func is_valid_section(section_id: int) -> bool:
	return section_id >= 0 and section_id < get_section_count()


func apply_damage(section_id: int, amount: float) -> void:
	if amount <= 0.0 or not is_valid_section(section_id):
		return
	set_health(section_id, _health[section_id] - amount)


func restore(section_id: int, amount: float) -> void:
	if amount <= 0.0 or not is_valid_section(section_id):
		return
	set_health(section_id, _health[section_id] + amount)


func set_health(section_id: int, value: float) -> void:
	if not is_valid_section(section_id):
		return

	var previous_health := _health[section_id]
	var next_health := clampf(value, 0.0, balance.max_health)
	if is_equal_approx(previous_health, next_health):
		return

	_health[section_id] = next_health
	_update_critical_state(section_id)
	section_changed.emit(
		section_id,
		next_health,
		balance.max_health,
		get_health_percent(section_id)
	)

	if previous_health > 0.0 and is_zero_approx(next_health):
		section_destroyed.emit(section_id)


func get_health(section_id: int) -> float:
	if not is_valid_section(section_id):
		return 0.0
	return _health[section_id]


func get_health_percent(section_id: int) -> float:
	if not is_valid_section(section_id) or balance.max_health <= 0.0:
		return 0.0
	return _health[section_id] / balance.max_health * 100.0


func is_critical(section_id: int) -> bool:
	if not is_valid_section(section_id):
		return false
	return _critical_states[section_id]


func needs_direction_indicator(section_id: int) -> bool:
	return (
		is_valid_section(section_id)
		and get_health_percent(section_id) <= balance.indicator_threshold_percent
	)


func get_section_color(section_id: int) -> Color:
	if section_id >= 0 and section_id < balance.section_colors.size():
		return balance.section_colors[section_id]
	return Color.WHITE


func get_state_summary() -> String:
	var parts := PackedStringArray()
	for section_id in range(get_section_count()):
		parts.append(
			"%d:%.0f%%" % [section_id + 1, get_health_percent(section_id)]
		)
	return "  ".join(parts)


func _initialize_sections() -> void:
	_health = PackedFloat32Array()
	_critical_states.clear()
	_health.resize(balance.section_count)
	for section_id in range(balance.section_count):
		_health[section_id] = balance.max_health
		_critical_states.append(false)
		section_changed.emit(
			section_id,
			balance.max_health,
			balance.max_health,
			100.0
		)


func _update_critical_state(section_id: int) -> void:
	var was_critical := _critical_states[section_id]
	var is_now_critical := (
		get_health_percent(section_id) <= balance.critical_threshold_percent
	)
	if was_critical == is_now_critical:
		return
	_critical_states[section_id] = is_now_critical
	if is_now_critical:
		section_entered_critical.emit(section_id)
	else:
		section_left_critical.emit(section_id)
