class_name CrewReplacementController
extends Node

signal replacement_started(defender_id: int, duration_seconds: float)
signal replacement_completed(defender_id: int, defender: Defender)
signal respawn_multiplier_changed(multiplier: float)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("CrewManager") var crew_manager_path: NodePath
@export_node_path("CrewRoleManager") var role_manager_path: NodePath = NodePath(
	"../World/Platform/CrewRoleManager"
)
@export_node_path("BoardingMovementResolver") var movement_resolver_path: NodePath
@export_node_path("PlatformVisualController") var portal_visual_path: NodePath = NodePath(
	"../World/Platform/PlatformVisualController"
)
@export var balance: CrewBalance
@export var instant_respawn_for_tests: bool = true

var _pending: Dictionary[int, CrewReplacementRuntime] = {}
var _portal_animating: Dictionary[int, bool] = {}
var _respawn_time_multiplier: float = 1.0

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _crew: CrewManager = get_node(crew_manager_path)
@onready var _portal: PlatformVisualController = get_node_or_null(
	portal_visual_path
) as PlatformVisualController


func _ready() -> void:
	assert(balance != null, "CrewReplacementController requires CrewBalance")
	_crew.defender_died.connect(_on_defender_died)
	if _portal != null:
		_portal.spawn_sequence_finished.connect(_on_portal_spawn_finished)


func _physics_process(delta: float) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	if _pending.is_empty():
		return

	var pending_ids: Array[int] = _pending.keys()
	var ready_ids: Array[int] = []
	for defender_id: int in pending_ids:
		if _portal_animating.has(defender_id):
			continue
		var runtime: CrewReplacementRuntime = _pending[defender_id]
		if runtime.tick(delta):
			ready_ids.append(defender_id)

	for defender_id: int in ready_ids:
		_begin_portal_spawn(defender_id)


func multiply_respawn_time(multiplier: float) -> bool:
	if multiplier <= 0.0:
		return false
	_respawn_time_multiplier *= multiplier
	respawn_multiplier_changed.emit(_respawn_time_multiplier)
	return true


func get_respawn_time_multiplier() -> float:
	return _respawn_time_multiplier


func get_current_respawn_delay() -> float:
	if instant_respawn_for_tests:
		return 0.0
	return balance.replacement_delay_seconds * _respawn_time_multiplier


func reset_run_modifiers() -> void:
	_pending.clear()
	_portal_animating.clear()
	_respawn_time_multiplier = 1.0
	respawn_multiplier_changed.emit(_respawn_time_multiplier)


func is_replacement_pending(defender_id: int) -> bool:
	return _pending.has(defender_id)


func get_remaining_seconds(defender_id: int) -> float:
	var runtime: CrewReplacementRuntime = _pending.get(defender_id)
	if runtime == null:
		return 0.0
	return runtime.remaining_seconds


func get_pending_count() -> int:
	return _pending.size()


func complete_replacement_now(defender_id: int) -> Defender:
	_pending.erase(defender_id)
	_portal_animating.erase(defender_id)
	var spawn_x: float = balance.replacement_door_local_x
	var defender: Defender = _crew.replace_defender(defender_id, spawn_x)
	if defender != null:
		replacement_completed.emit(defender_id, defender)
	return defender


func get_summary() -> String:
	if _pending.is_empty():
		return "НЕТ"
	var ids: Array[int] = _pending.keys()
	ids.sort()
	var parts := PackedStringArray()
	for defender_id: int in ids:
		var state_text: String = (
			"портал"
			if _portal_animating.has(defender_id)
			else "%.1fс" % get_remaining_seconds(defender_id)
		)
		parts.append("%d:%s" % [defender_id + 1, state_text])
	return "  ".join(parts)


func _on_defender_died(defender_id: int) -> void:
	var current: Defender = _crew.get_defender(defender_id)
	if current != null and current.health.is_alive():
		return
	if _pending.has(defender_id):
		return
	var runtime := CrewReplacementRuntime.new(
		defender_id,
		get_current_respawn_delay()
	)
	_pending[defender_id] = runtime
	replacement_started.emit(defender_id, runtime.remaining_seconds)
	if runtime.remaining_seconds <= 0.0:
		call_deferred("_begin_portal_spawn", defender_id)


func _begin_portal_spawn(defender_id: int) -> void:
	if not _pending.has(defender_id):
		return
	if _portal_animating.has(defender_id):
		return
	if _portal == null:
		complete_replacement_now(defender_id)
		return
	_portal_animating[defender_id] = true
	_portal.play_spawn(defender_id)


func _on_portal_spawn_finished(defender_id: int) -> void:
	if not _pending.has(defender_id):
		_portal_animating.erase(defender_id)
		return
	complete_replacement_now(defender_id)
