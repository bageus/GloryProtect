class_name DefenderDurabilityComponent
extends Node

signal armor_changed(current_armor: int, max_armor: int)
signal lethal_guard_consumed
signal next_hit_guard_consumed

var _base_max_armor: int = 0
var _base_current_armor: int = 0
var _role_max_armor: int = 0
var _role_current_armor: int = 0
var _temporary_armor: int = 0
var _lethal_guard_available: bool = false
var _next_hit_guard_available: bool = false


func configure(max_armor: int, lethal_guard_available: bool) -> void:
	_base_max_armor = maxi(0, max_armor)
	_base_current_armor = _base_max_armor
	_role_max_armor = 0
	_role_current_armor = 0
	_temporary_armor = 0
	_lethal_guard_available = lethal_guard_available
	_next_hit_guard_available = false
	_emit_armor_changed()


func resolve_incoming_damage(
	amount: int,
	current_health: int
) -> int:
	if amount <= 0 or current_health <= 0:
		return 0
	if _next_hit_guard_available:
		_next_hit_guard_available = false
		next_hit_guard_consumed.emit()
		return 0

	var remaining: int = amount
	remaining = _absorb_from_temporary(remaining)
	remaining = _absorb_from_role(remaining)
	remaining = _absorb_from_base(remaining)
	if remaining >= current_health and _lethal_guard_available:
		_lethal_guard_available = false
		lethal_guard_consumed.emit()
		return maxi(0, current_health - 1)
	return remaining


func set_max_armor(new_max_armor: int) -> void:
	var resolved: int = maxi(0, new_max_armor)
	if resolved == _base_max_armor:
		return
	if resolved > _base_max_armor:
		_base_current_armor += resolved - _base_max_armor
	_base_max_armor = resolved
	_base_current_armor = mini(_base_current_armor, _base_max_armor)
	_emit_armor_changed()


func set_role_armor_pool(max_armor: int, current_armor: int) -> void:
	_role_max_armor = maxi(0, max_armor)
	_role_current_armor = clampi(current_armor, 0, _role_max_armor)
	_emit_armor_changed()


func take_role_armor_pool() -> int:
	var remaining: int = _role_current_armor
	_role_max_armor = 0
	_role_current_armor = 0
	_emit_armor_changed()
	return remaining


func add_temporary_armor(amount: int) -> void:
	if amount <= 0:
		return
	_temporary_armor += amount
	_emit_armor_changed()


func clear_temporary_armor() -> void:
	if _temporary_armor == 0:
		return
	_temporary_armor = 0
	_emit_armor_changed()


func set_next_hit_guard_available(available: bool) -> void:
	_next_hit_guard_available = available


func set_lethal_guard_available(available: bool) -> void:
	_lethal_guard_available = available


func restore_armor(amount: int) -> void:
	if amount <= 0:
		return
	var remaining: int = amount
	var base_missing: int = _base_max_armor - _base_current_armor
	var base_restore: int = mini(base_missing, remaining)
	_base_current_armor += base_restore
	remaining -= base_restore
	if remaining > 0:
		_role_current_armor = mini(
			_role_max_armor,
			_role_current_armor + remaining
		)
	_emit_armor_changed()


func get_current_armor() -> int:
	return _base_current_armor + _role_current_armor + _temporary_armor


func get_max_armor() -> int:
	return _base_max_armor + _role_max_armor + _temporary_armor


func get_base_current_armor() -> int:
	return _base_current_armor


func get_base_max_armor() -> int:
	return _base_max_armor


func get_role_current_armor() -> int:
	return _role_current_armor


func get_role_max_armor() -> int:
	return _role_max_armor


func get_temporary_armor() -> int:
	return _temporary_armor


func has_lethal_guard() -> bool:
	return _lethal_guard_available


func has_next_hit_guard() -> bool:
	return _next_hit_guard_available


func _absorb_from_temporary(amount: int) -> int:
	if amount <= 0 or _temporary_armor <= 0:
		return amount
	var absorbed: int = mini(_temporary_armor, amount)
	_temporary_armor -= absorbed
	_emit_armor_changed()
	return amount - absorbed


func _absorb_from_role(amount: int) -> int:
	if amount <= 0 or _role_current_armor <= 0:
		return amount
	var absorbed: int = mini(_role_current_armor, amount)
	_role_current_armor -= absorbed
	_emit_armor_changed()
	return amount - absorbed


func _absorb_from_base(amount: int) -> int:
	if amount <= 0 or _base_current_armor <= 0:
		return amount
	var absorbed: int = mini(_base_current_armor, amount)
	_base_current_armor -= absorbed
	_emit_armor_changed()
	return amount - absorbed


func _emit_armor_changed() -> void:
	armor_changed.emit(get_current_armor(), get_max_armor())
