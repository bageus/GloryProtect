class_name Defender
extends Node2D

signal destination_reached(defender_id: int)
signal died(defender_id: int)

@export_node_path("HealthComponent") var health_path: NodePath
@export_node_path("StatusEffectComponent") var status_effects_path: NodePath
@export_node_path("DefenderMovement") var movement_path: NodePath
@export_node_path("DefenderVisual") var visual_path: NodePath
@export_node_path("MeleeAttackComponent") var melee_path: NodePath
@export_node_path("DefenderCombatController") var combat_path: NodePath

var defender_id: int = -1
var _balance: CrewBalance
var _body_color: Color = Color(0.45, 0.8, 1.0)

@onready var health: HealthComponent = get_node(health_path)
@onready var status_effects: StatusEffectComponent = get_node(status_effects_path)
@onready var movement: DefenderMovement = get_node(movement_path)
@onready var visual: DefenderVisual = get_node(visual_path)
@onready var melee: MeleeAttackComponent = get_node(melee_path)
@onready var combat: DefenderCombatController = get_node(combat_path)


func _ready() -> void:
	movement.destination_reached.connect(_on_destination_reached)
	health.depleted.connect(_on_depleted)
	_apply_configuration()


func configure(
	new_defender_id: int,
	balance: CrewBalance,
	body_color: Color
) -> void:
	defender_id = new_defender_id
	_balance = balance
	_body_color = body_color
	if is_node_ready():
		_apply_configuration()


func move_to(local_x: float) -> void:
	if health.is_alive():
		movement.move_to(local_x)


func teleport_to(local_x: float) -> void:
	movement.teleport_to(local_x)


func is_moving() -> bool:
	return movement.is_moving()


func is_combat_action_active() -> bool:
	return combat.is_action_active()


func _apply_configuration() -> void:
	if _balance == null:
		return
	health.configure(_balance.defender_max_health)
	movement.configure(_balance.defender_move_speed)
	visual.configure(_balance.defender_body_radius, _body_color)
	position.y = _balance.defender_local_y
	visible = true


func _on_destination_reached() -> void:
	destination_reached.emit(defender_id)


func _on_depleted() -> void:
	status_effects.clear_poison()
	movement.stop()
	combat.cancel()
	visible = false
	died.emit(defender_id)
