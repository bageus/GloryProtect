class_name PrototypeShieldSystem
extends Node

signal health_changed(current_health: float, max_health: float)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("PrototypeWorld") var world_path: NodePath
@export_range(1.0, 1000.0, 1.0) var max_health: float = 100.0
@export_range(0.0, 100.0, 0.1) var recharge_per_second: float = 8.0
@export_range(0.0, 100.0, 1.0) var debug_damage_amount: float = 10.0

var current_health: float = 100.0

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _world: PrototypeWorld = get_node(world_path)


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func _process(delta: float) -> void:
	if not _game_flow.is_world_simulation_active():
		return

	# Temporary prototype helper. Space damages the test section so recharge can
	# be verified before strategic waves are implemented.
	if Input.is_action_just_pressed(&"ui_accept"):
		apply_damage(debug_damage_amount)

	if _world.is_contact_active() and current_health < max_health:
		set_health(current_health + recharge_per_second * delta)


func apply_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	set_health(current_health - amount)


func restore(amount: float) -> void:
	if amount <= 0.0:
		return
	set_health(current_health + amount)


func set_health(value: float) -> void:
	var next_health := clampf(value, 0.0, max_health)
	if is_equal_approx(next_health, current_health):
		return
	current_health = next_health
	health_changed.emit(current_health, max_health)


func get_health_percent() -> float:
	if max_health <= 0.0:
		return 0.0
	return current_health / max_health * 100.0
