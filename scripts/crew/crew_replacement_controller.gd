class_name CrewReplacementController
extends Node

signal replacement_started(defender_id: int, duration_seconds: float)
signal replacement_completed(defender_id: int, defender: Defender)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("CrewManager") var crew_manager_path: NodePath
@export_node_path("BoardingMovementResolver") var movement_resolver_path: NodePath
@export var balance: CrewBalance

var _pending: Dictionary[int, CrewReplacementRuntime] = {}

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _crew: CrewManager = get_node(crew_manager_path)
@onready var _movement_resolver: BoardingMovementResolver = get_node(
	movement_resolver_path
)


func _ready() -> void:
	assert(balance != null, "CrewReplacementController requires CrewBalance")
	_crew.defender_died.connect(_on_defender_died)


func _physics_process(delta: float) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	if _pending.is_empty():
		return

	var pending_ids: Array[int] = _pending.keys()
	var completed_ids: Array[int] = []
	for defender_id: int in pending_ids:
		var runtime: CrewReplacementRuntime = _pending[defender_id]
		if runtime.tick(delta):
			completed_ids.append(defender_id)

	for defender_id: int in completed_ids:
		_complete_replacement(defender_id)


func is_replacement_pending(defender_id: int) -> bool:
	return _pending.has(defender_id)


func get_remaining_seconds(defender_id: int) -> float:
	var runtime: CrewReplacementRuntime = _pending.get(defender_id)
	if runtime == null:
		return 0.0
	return runtime.remaining_seconds


func get_pending_count() -> int:
	return _pending.size()


func get_summary() -> String:
	if _pending.is_empty():
		return "НЕТ"
	var ids: Array[int] = _pending.keys()
	ids.sort()
	var parts := PackedStringArray()
	for defender_id: int in ids:
		parts.append(
			"%d:%.1fс" % [
				defender_id + 1,
				get_remaining_seconds(defender_id),
			]
		)
	return "  ".join(parts)


func _on_defender_died(defender_id: int) -> void:
	if _pending.has(defender_id):
		return
	var runtime: CrewReplacementRuntime = CrewReplacementRuntime.new(
		defender_id,
		balance.replacement_delay_seconds
	)
	_pending[defender_id] = runtime
	replacement_started.emit(defender_id, runtime.remaining_seconds)


func _complete_replacement(defender_id: int) -> void:
	if not _pending.has(defender_id):
		return
	_pending.erase(defender_id)
	var spawn_x: float = _movement_resolver.find_nearest_defender_slot(
		balance.replacement_door_local_x
	)
	var defender: Defender = _crew.replace_defender(defender_id, spawn_x)
	if defender != null:
		replacement_completed.emit(defender_id, defender)
