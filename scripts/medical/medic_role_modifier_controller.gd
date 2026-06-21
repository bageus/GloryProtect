class_name MedicRoleModifierController
extends Node

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

@onready var _crew: CrewManager = get_node(crew_manager_path)
@onready var _roles: CrewRoleManager = get_node(role_manager_path)
@onready var _medical: MedicalStationSystem = get_node(medical_system_path)


func _ready() -> void:
	_roles.assignment_changed.connect(_on_assignment_changed)
	_medical.upgrades_changed.connect(_on_upgrades_changed)
	_crew.defender_replaced.connect(_on_defender_replaced)
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


func _resolve_active_medic_id() -> int:
	var owner_id: int = _roles.get_role_owner(CrewRole.Id.MEDIC)
	if owner_id < 0:
		return -1
	var assignment: CrewAssignmentRuntime = _roles.get_assignment(owner_id)
	if assignment == null or assignment.current_role != CrewRole.Id.MEDIC:
		return -1
	if assignment.state not in [
		CrewAssignmentRuntime.State.ACTIVE,
		CrewAssignmentRuntime.State.WAITING_FOR_ACTION,
	]:
		return -1
	var defender: Defender = _crew.get_defender(owner_id)
	if defender == null or not defender.health.is_alive():
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
		var underlying_max: int = maxi(
			1,
			defender.health.max_health - _applied_health_bonus
		)
		var role_health_remaining: int = clampi(
			defender.health.current_health - underlying_max,
			0,
			_applied_health_bonus
		)
		defender.health.set_max_health(underlying_max, false)
		var role_armor_remaining: int = defender.durability.take_role_armor_pool()
		_stored_health_segments = (
			_known_health_bonus if died else role_health_remaining
		)
		_stored_armor_segments = (
			_known_armor_bonus if died else role_armor_remaining
		)
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
	var base_max: int = defender.health.max_health
	var base_current: int = defender.health.current_health
	defender.health.set_max_health(base_max + _applied_health_bonus, false)
	defender.health.set_health(
		base_current + mini(_stored_health_segments, _applied_health_bonus)
	)
	defender.durability.set_role_armor_pool(
		_applied_armor_bonus,
		mini(_stored_armor_segments, _applied_armor_bonus)
	)
	_stored_health_segments = 0
	_stored_armor_segments = 0


func _apply_capacity_change_to_active() -> void:
	var defender: Defender = _crew.get_defender(_active_medic_id)
	if defender == null or not defender.health.is_alive():
		return
	if _applied_health_bonus != _known_health_bonus:
		var underlying_max: int = maxi(
			1,
			defender.health.max_health - _applied_health_bonus
		)
		var underlying_current: int = mini(
			defender.health.current_health,
			underlying_max
		)
		var role_current: int = clampi(
			defender.health.current_health - underlying_max,
			0,
			_applied_health_bonus
		)
		if _known_health_bonus > _applied_health_bonus:
			role_current += _known_health_bonus - _applied_health_bonus
		role_current = mini(role_current, _known_health_bonus)
		defender.health.set_max_health(
			underlying_max + _known_health_bonus,
			false
		)
		defender.health.set_health(underlying_current + role_current)
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


func _on_assignment_changed(
	_defender_id: int,
	_current_role: int,
	_target_role: int,
	_state: int
) -> void:
	call_deferred("_refresh")


func _on_upgrades_changed() -> void:
	call_deferred("_refresh")


func _on_defender_replaced(_defender_id: int, _defender: Defender) -> void:
	call_deferred("_refresh")
