class_name CrewFailureController
extends Node

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("CrewManager") var crew_manager_path: NodePath

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _crew: CrewManager = get_node(crew_manager_path)


func _ready() -> void:
	_crew.defender_died.connect(_on_defender_died)


func _on_defender_died(_defender_id: int) -> void:
	if _crew.get_living_count() == 0:
		_game_flow.end_run(&"all_defenders_dead")
