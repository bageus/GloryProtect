class_name MedicRevivalController
extends Node

signal revival_reserved(defender_id: int, cooldown: float)
signal revival_completed(defender_id: int, defender: Defender)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("CrewManager") var crew_manager_path: NodePath
@export_node_path("CrewReplacementController") var replacement_controller_path: NodePath
@export_node_path("MedicalStationSystem") var medical_system_path: NodePath

var _cooldown_remaining: float = 0.0
var _scheduled_defender_id: int = -1

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _crew: CrewManager = get_node(crew_manager_path)
@onready var _replacements: CrewReplacementController = get_node(
	replacement_controller_path
)
@onready var _medical: MedicalStationSystem = get_node(medical_system_path)


func _ready() -> void:
	_game_flow.run_state_changed.connect(_on_run_state_changed)


func _physics_process(delta: float) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	_cooldown_remaining = maxf(
		0.0,
		_cooldown_remaining - maxf(0.0, delta)
	)


func can_revive() -> bool:
	return (
		_medical.upgrades.revival_enabled
		and _cooldown_remaining <= 0.0
		and _scheduled_defender_id < 0
	)


func try_schedule_revival(defender_id: int) -> bool:
	if not can_revive():
		return false
	var defender: Defender = _crew.get_defender(defender_id)
	if defender == null or defender.health.is_alive():
		return false
	_scheduled_defender_id = defender_id
	_cooldown_remaining = _medical.upgrade_balance.revival_cooldown
	revival_reserved.emit(defender_id, _cooldown_remaining)
	call_deferred("_perform_scheduled_revival")
	return true


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func _perform_scheduled_revival() -> void:
	var defender_id: int = _scheduled_defender_id
	_scheduled_defender_id = -1
	if defender_id < 0:
		return
	var current: Defender = _crew.get_defender(defender_id)
	if current != null and current.health.is_alive():
		return
	var replacement: Defender = _replacements.complete_replacement_now(defender_id)
	if replacement != null:
		revival_completed.emit(defender_id, replacement)


func _on_run_state_changed(previous_state: int, new_state: int) -> void:
	if new_state != GameFlowController.RunState.START_DELAY:
		return
	if previous_state == GameFlowController.RunState.MANUAL_PAUSE:
		return
	_cooldown_remaining = 0.0
	_scheduled_defender_id = -1
