class_name MedicStimulantController
extends Node

signal stimulant_applied(defender_id: int, duration: float)
signal stimulant_expired(defender_id: int)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("CrewManager") var crew_manager_path: NodePath
@export_node_path("MedicalStationSystem") var medical_system_path: NodePath

var _remaining_by_defender: Dictionary[int, float] = {}

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _crew: CrewManager = get_node(crew_manager_path)
@onready var _medical: MedicalStationSystem = get_node(medical_system_path)


func _ready() -> void:
	_medical.segment_restored.connect(_on_segment_restored)
	_medical.upgrades_changed.connect(_on_upgrades_changed)
	_crew.defender_died.connect(_on_defender_died)
	_crew.defender_replaced.connect(_on_defender_replaced)
	_game_flow.run_state_changed.connect(_on_run_state_changed)


func _physics_process(delta: float) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	var defender_ids: Array[int] = _remaining_by_defender.keys()
	for defender_id: int in defender_ids:
		var defender: Defender = _crew.get_defender(defender_id)
		if defender == null or not defender.health.is_alive():
			_clear_defender(defender_id)
			continue
		var remaining: float = maxf(
			0.0,
			float(_remaining_by_defender[defender_id]) - maxf(0.0, delta)
		)
		if remaining <= 0.0:
			_clear_defender(defender_id)
		else:
			_remaining_by_defender[defender_id] = remaining


func get_remaining(defender_id: int) -> float:
	return float(_remaining_by_defender.get(defender_id, 0.0))


func is_active(defender_id: int) -> bool:
	return get_remaining(defender_id) > 0.0


func clear_all() -> void:
	var defender_ids: Array[int] = _remaining_by_defender.keys()
	for defender_id: int in defender_ids:
		_clear_defender(defender_id)


func _on_segment_restored(
	_medic_id: int,
	target_id: int,
	amount: int
) -> void:
	if amount <= 0 or not _medical.upgrades.stimulant_enabled:
		return
	var defender: Defender = _crew.get_defender(target_id)
	if defender == null or not defender.health.is_alive():
		return
	var attack_multiplier: float = (
		1.0 + _medical.upgrade_balance.stimulant_attack_speed_bonus_ratio
	)
	var move_multiplier: float = (
		1.0 + _medical.upgrade_balance.stimulant_move_speed_bonus_ratio
	)
	defender.set_temporary_action_multipliers(
		attack_multiplier,
		move_multiplier
	)
	_remaining_by_defender[target_id] = (
		_medical.upgrade_balance.stimulant_duration
	)
	stimulant_applied.emit(
		target_id,
		_medical.upgrade_balance.stimulant_duration
	)


func _clear_defender(defender_id: int) -> void:
	var existed: bool = _remaining_by_defender.erase(defender_id)
	var defender: Defender = _crew.get_defender(defender_id)
	if defender != null and is_instance_valid(defender):
		defender.clear_temporary_action_multipliers()
	if existed:
		stimulant_expired.emit(defender_id)


func _on_upgrades_changed() -> void:
	if not _medical.upgrades.stimulant_enabled:
		clear_all()


func _on_defender_died(defender_id: int) -> void:
	_clear_defender(defender_id)


func _on_defender_replaced(defender_id: int, _defender: Defender) -> void:
	_clear_defender(defender_id)


func _on_run_state_changed(previous_state: int, new_state: int) -> void:
	if new_state != GameFlowController.RunState.START_DELAY:
		return
	if previous_state == GameFlowController.RunState.MANUAL_PAUSE:
		return
	clear_all()
