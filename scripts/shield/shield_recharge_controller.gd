class_name ShieldRechargeController
extends Node

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("OrbContactSystem") var contact_system_path: NodePath
@export_node_path("ShieldSystem") var shield_system_path: NodePath
@export var anchorless_control_path: NodePath
@export var balance: ShieldBalance

var _anchorless: AnchorlessControlSystem

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _contact: OrbContactSystem = get_node(contact_system_path)
@onready var _shield: ShieldSystem = get_node(shield_system_path)


func _ready() -> void:
	assert(balance != null, "ShieldRechargeController requires ShieldBalance")
	process_physics_priority = -5
	if not anchorless_control_path.is_empty():
		_anchorless = get_node_or_null(anchorless_control_path) as AnchorlessControlSystem


func _physics_process(delta: float) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	var section_id := _contact.get_active_section_id()
	if section_id < 0:
		return
	var multiplier: float = 1.0
	if _anchorless != null:
		multiplier = _anchorless.get_shield_recharge_multiplier(
			_contact.get_active_orb_id()
		)
	_shield.restore(section_id, balance.recharge_per_second * multiplier * delta)
