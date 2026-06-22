class_name MedicRoleModifierController
extends Node

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("CrewManager") var crew_manager_path: NodePath
@export_node_path("CrewRoleManager") var role_manager_path: NodePath
@export_node_path("MedicalStationSystem") var medical_system_path: NodePath

var _active_medic_id: int = -1
var _applied_health_bonus: int = 0
var _applied_armor_bonus: int = 0
var _known_health_bonus: int = 0
var _known_armor_bonus: int = 0
var _stored_health_segments: int = 0
var _stored_armor_segments: int = 0

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _crew: CrewManager = get_node(crew_manager_path)
@onready var _roles: CrewRoleManager = get_node(role_manager_path)
@onready var _medical: MedicalStationSystem = get_node(medical_system_path)


func _ready() -> void:
	_roles.assignment_changed.connect(_on_assignment_changed)
	_medical.upgrades_changed.connect(_on_upgrades_changed)
	_medical.healing_started.connect(_on_healing_started)
	_medical.healing_stopped.connect(_on_healing_stopped)
	_crew.defender_died.connect(_on_defender_died)
	_crew.defender_replaced.connect(_on_defender_replaced)
	_game_flow.run_state_changed.connect(_on_run_state_changed)
	call_deferred("_refresh")


func get_active_medic_id() -> int:
	return _active_medic_id


func get_stored_health_segments() -> int:
	return _stored_health_segments


func get_stored_armor_segments() -> int:
	return _stored_armor_segments


func _refresh() -> void:
	_sync_upgrade_capacities()
	var next_medic_id: int = _resolve_active_medic_id()
	if next_medic_id != _active_medic_id:
		_detach_current_medic()
		_attach_medic(next_medic_id)
		return
	if _active_medic_id >= 0:
		_apply_capacity_change_to_active()
		_apply_action_modifiers_to_active()


func _resolve_active_medic_id() -> int:
	var owner_id: int = _roles.get_role_owner(CrewRole.Id.MEDIC)
	if owner_id < 0:
		return -1
	var assignment: CrewAssignmentRuntime = _roles.get_assignment(owner_id)
	if assignment == null or assignment.current_role != CrewRole.Id.MEDIC:
		return -1
	var defender: Defender = _crew.get_defender(owner_id)
	if defender == null or not defender.health.is_alive():
		return -1
	if assignment.state == CrewAssignmentRuntime.State.WAITING_FOR_ACTION:
		if (
			not _medical.is_healing_cycle_active(owner_id)
			and not defender.is_combat_action_active()
		):
			return -1
	elif assignment.state != CrewAssignmentRuntime.State.ACTIVE:
		return -1
	return owner_id


func _sync_upgrade_capacities() -> void:
	var next_health: int = maxi(0, _medical.upgrades.role_health_bonus)
	var next_armor: int = maxi(0, _medical.upgrades.role_armor_bonus)
	if _active_medic_id < 0:
		_stored_health_segments = _resize_stored_pool(
			_stored_health_segments,
			_known_health_bonus,
			next_health
		)
		_stored_armor_segments = _resize_stored_pool(
			_stored_armor_segments,
			_known_armor_bonus,
			next_armor
		)
	_known_health_bonus = next_health
	_known_armor_bonus = next_armor


func _resize_stored_pool(current: int, previous_max: int, next_max: int) -> int:
	if next_max > previous_max:
		return mini(next_max, current + next_max - previous_max)
	return mini(current, next_max)


func _detach_current_medic() -> void:
	if _active_medic_id < 0:
		return
	var defender: Defender = _crew.get_defender(_active_medic_id)
	if defender != null and is_instance_valid(defender):
		var died: bool = not defender.health.is_alive()
		var role_health_remaining: int = defender.take_medic_role_health_pool()
		var role_armor_remaining: int = defender.durability.take_role_armor_pool()
		_stored_health_segments = (
			_known_health_bonus if died else role_health_remaining
		)
		_stored_armor_segments = (
			_known_armor_bonus if died else role_armor_remaining
		)
		defender.set_medic_role_modifiers(false, false, 0, 1.0)
	_active_medic_id = -1
	_applied_health_bonus = 0
	_applied_armor_bonus = 0


func _attach_medic(defender_id: int) -> void:
	if defender_id < 0:
		return
	var defender: Defender = _crew.get_defender(defender_id)
	if defender == null or not defender.health.is_alive():
		return
	_active_medic_id = defender_id
	_applied_health_bonus = _known_health_bonus
	_applied_armor_bonus = _known_armor_bonus
	defender.set_medic_role_health_pool(
		_applied_health_bonus,
		mini(_stored_health_segments, _applied_health_bonus)
	)
	defender.durability.set_role_armor_pool(
		_applied_armor_bonus,
		mini(_stored_armor_segments, _applied_armor_bonus)
	)
	_stored_health_segments = 0
	_stored_armor_segments = 0
	_apply_action_modifiers_to_active()
	defender.set_medic_healing_action_active(
		_medical.is_healing_cycle_active(defender_id)
	)


func _apply_capacity_change_to_active() -> void:
	var defender: Defender = _crew.get_defender(_active_medic_id)
	if defender == null or not defender.health.is_alive():
		return
	if _applied_health_bonus != _known_health_bonus:
		var role_health: int = defender.get_medic_role_health_current()
		if _known_health_bonus > _applied_health_bonus:
			role_health += _known_health_bonus - _applied_health_bonus
		defender.set_medic_role_health_pool(
			_known_health_bonus,
			mini(role_health, _known_health_bonus)
		)
		_applied_health_bonus = _known_health_bonus
	if _applied_armor_bonus != _known_armor_bonus:
		var role_armor: int = defender.durability.get_role_current_armor()
		if _known_armor_bonus > _applied_armor_bonus:
			role_armor += _known_armor_bonus - _applied_armor_bonus
		defender.durability.set_role_armor_pool(
			_known_armor_bonus,
			mini(role_armor, _known_armor_bonus)
		)
		_applied_armor_bonus = _known_armor_bonus


func _apply_action_modifiers_to_active() -> void:
	if _active_medic_id < 0:
		return
	var defender: Defender = _crew.get_defender(_active_medic_id)
	if defender == null or not defender.health.is_alive():
		return
	var is_field: bool = (
		_medical.upgrades.specialization_id == MedicUpgradeRuntime.FIELD
	)
	var combat_enabled: bool = is_field and _medical.upgrades.field_combat_enabled
	var damage_bonus: int = (
		_medical.upgrade_balance.field_attack.damage_bonus
		if combat_enabled
		else 0
	)
	var movement_multiplier: float = (
		1.0 + _medical.upgrade_balance.field_move_speed_bonus_ratio
		if is_field
		else 1.0
	)
	defender.set_medic_role_modifiers(
		true,
		combat_enabled,
		damage_bonus,
		movement_multiplier
	)


func _reset_for_run() -> void:
	_detach_current_medic()
	_known_health_bonus = 0
	_known_armor_bonus = 0
	_stored_health_segments = 0
	_stored_armor_segments = 0


func _on_assignment_changed(
	_defender_id: int,
	_current_role: int,
	_target_role: int,
	_state: int
) -> void:
	call_deferred("_refresh")


func _on_upgrades_changed() -> void:
	call_deferred("_refresh")


func _on_healing_started(medic_id: int, _target_id: int) -> void:
	var defender: Defender = _crew.get_defender(medic_id)
	if defender != null:
		defender.set_medic_healing_action_active(true)


func _on_healing_stopped(medic_id: int, _target_id: int) -> void:
	var defender: Defender = _crew.get_defender(medic_id)
	if defender == null:
		return
	defender.set_medic_healing_action_active(false)
	var assignment: CrewAssignmentRuntime = _roles.get_assignment(medic_id)
	if (
		assignment != null
		and assignment.state == CrewAssignmentRuntime.State.WAITING_FOR_ACTION
		and medic_id == _active_medic_id
	):
		_detach_current_medic()


func _on_defender_died(defender_id: int) -> void:
	if defender_id != _active_medic_id:
		return
	var defender: Defender = _crew.get_defender(defender_id)
	if defender != null and is_instance_valid(defender):
		defender.take_medic_role_health_pool()
		defender.durability.take_role_armor_pool()
		defender.set_medic_role_modifiers(false, false, 0, 1.0)
	_stored_health_segments = _known_health_bonus
	_stored_armor_segments = _known_armor_bonus
	_active_medic_id = -1
	_applied_health_bonus = 0
	_applied_armor_bonus = 0


func _on_defender_replaced(_defender_id: int, _defender: Defender) -> void:
	call_deferred("_refresh")


func _on_run_state_changed(previous_state: int, new_state: int) -> void:
	if new_state != GameFlowController.RunState.START_DELAY:
		return
	if previous_state == GameFlowController.RunState.MANUAL_PAUSE:
		return
	call_deferred("_reset_for_run")
