class_name ShieldRechargeController
extends Node

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("OrbContactSystem") var contact_system_path: NodePath
@export_node_path("ShieldSystem") var shield_system_path: NodePath
@export var balance: ShieldBalance

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _contact: OrbContactSystem = get_node(contact_system_path)
@onready var _shield: ShieldSystem = get_node(shield_system_path)


func _ready() -> void:
	assert(balance != null, "ShieldRechargeController requires ShieldBalance")
	process_physics_priority = -5


func _physics_process(delta: float) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	var section_id := _contact.get_active_section_id()
	if section_id < 0:
		return
	_shield.restore(section_id, balance.recharge_per_second * delta)
