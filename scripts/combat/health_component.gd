class_name HealthComponent
extends Node

signal health_changed(current_health: int, max_health: int)
signal damage_applied(amount: int, current_health: int)
signal depleted

@export_range(1, 100, 1) var max_health: int = 3

var current_health: int = 3
var _durability: DefenderDurabilityComponent


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func configure(new_max_health: int) -> void:
	max_health = maxi(1, new_max_health)
	current_health = max_health
	if is_node_ready():
		health_changed.emit(current_health, max_health)


func set_durability_component(
	durability: DefenderDurabilityComponent
) -> void:
	_durability = durability


func apply_damage(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return
	var resolved_amount: int = amount
	if _durability != null and is_instance_valid(_durability):
		resolved_amount = _durability.resolve_incoming_damage(
			amount,
			current_health
		)
	if resolved_amount <= 0:
		return
	var previous_health: int = current_health
	set_health(current_health - resolved_amount)
	if current_health != previous_health:
		damage_applied.emit(previous_health - current_health, current_health)


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
