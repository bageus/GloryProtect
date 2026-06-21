class_name DefenderDurabilityComponent
extends Node

signal armor_changed(current_armor: int, max_armor: int)
signal lethal_guard_consumed

var _max_armor: int = 0
var _current_armor: int = 0
var _lethal_guard_available: bool = false


func configure(max_armor: int, lethal_guard_available: bool) -> void:
	_max_armor = maxi(0, max_armor)
	_current_armor = _max_armor
	_lethal_guard_available = lethal_guard_available
	armor_changed.emit(_current_armor, _max_armor)


func resolve_incoming_damage(
	amount: int,
	current_health: int
) -> int:
	if amount <= 0 or current_health <= 0:
		return 0
	var remaining: int = amount
	if _current_armor > 0:
		var absorbed: int = mini(_current_armor, remaining)
		_current_armor -= absorbed
		remaining -= absorbed
		armor_changed.emit(_current_armor, _max_armor)
	if (
		remaining >= current_health
		and _lethal_guard_available
		and current_health > 1
	):
		_lethal_guard_available = false
		lethal_guard_consumed.emit()
		return current_health - 1
	return remaining


func add_armor(amount: int) -> void:
	if amount <= 0:
		return
	_max_armor += amount
	_current_armor += amount
	armor_changed.emit(_current_armor, _max_armor)


func restore_armor(amount: int) -> void:
	if amount <= 0 or _current_armor >= _max_armor:
		return
	_current_armor = mini(_max_armor, _current_armor + amount)
	armor_changed.emit(_current_armor, _max_armor)


func get_current_armor() -> int:
	return _current_armor


func get_max_armor() -> int:
	return _max_armor


func has_lethal_guard() -> bool:
	return _lethal_guard_available
