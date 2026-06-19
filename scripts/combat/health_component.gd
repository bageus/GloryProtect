class_name HealthComponent
extends Node

signal health_changed(current_health: int, max_health: int)
signal depleted

@export_range(1, 100, 1) var max_health: int = 3

var current_health: int = 3


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func configure(new_max_health: int) -> void:
	max_health = maxi(1, new_max_health)
	current_health = max_health
	if is_node_ready():
		health_changed.emit(current_health, max_health)


func apply_damage(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return
	set_health(current_health - amount)


func heal(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return
	set_health(current_health + amount)


func set_health(value: int) -> void:
	var next_health := clampi(value, 0, max_health)
	if next_health == current_health:
		return
	current_health = next_health
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		depleted.emit()


func is_alive() -> bool:
	return current_health > 0
