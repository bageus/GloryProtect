class_name ShieldFailureController
extends Node

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("ShieldSystem") var shield_system_path: NodePath

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _shield: ShieldSystem = get_node(shield_system_path)


func _ready() -> void:
	_shield.section_destroyed.connect(_on_section_destroyed)


func _on_section_destroyed(_section_id: int) -> void:
	_game_flow.end_run(&"shield_section_destroyed")
