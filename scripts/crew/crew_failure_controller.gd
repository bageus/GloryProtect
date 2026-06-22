class_name CrewFailureController
extends Node

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("CrewManager") var crew_manager_path: NodePath
@export_node_path("MedicRevivalController") var revival_controller_path: NodePath

var _revival: MedicRevivalController

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _crew: CrewManager = get_node(crew_manager_path)


func _ready() -> void:
	if not revival_controller_path.is_empty():
		_revival = get_node_or_null(revival_controller_path) as MedicRevivalController
	_crew.defender_died.connect(_on_defender_died)


func _on_defender_died(defender_id: int) -> void:
	if _crew.get_living_count() > 0:
		return
	if _revival != null:
		if _revival.is_revival_scheduled():
			return
		if _revival.try_schedule_revival(defender_id):
			return
	_game_flow.end_run(&"all_defenders_dead")
