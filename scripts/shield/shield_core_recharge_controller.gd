class_name ShieldCoreRechargeController
extends ShieldRechargeController

signal recharge_distributed(
	primary_section_id: int,
	primary_amount: float,
	secondary_section_id: int,
	secondary_amount: float
)

@export_node_path("AnchorlessControlSystem") var anchorless_control_path: NodePath

var _speed_multiplier: float = 1.0
var _distribution_ratio: float = 0.0
var _anchorless: AnchorlessControlSystem


func _ready() -> void:
	super._ready()
	if anchorless_control_path.is_empty():
		return
	set_anchorless_control(
		get_node_or_null(anchorless_control_path) as AnchorlessControlSystem
	)


func set_anchorless_control(value: AnchorlessControlSystem) -> void:
	_anchorless = value
	assert(_anchorless != null, "Anchorless control system is required")


func set_upgrade_modifiers(speed_multiplier: float, distribution_ratio: float) -> void:
	_speed_multiplier = maxf(0.0, speed_multiplier)
	_distribution_ratio = clampf(distribution_ratio, 0.0, 1.0)


func reset_upgrade_modifiers() -> void:
	set_upgrade_modifiers(1.0, 0.0)


func get_speed_multiplier() -> float:
	return _speed_multiplier


func get_distribution_ratio() -> float:
	return _distribution_ratio


func _physics_process(delta: float) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	var section_id := _contact.get_active_section_id()
	if section_id < 0:
		return
	var anchorless_multiplier: float = 1.0
	if _anchorless != null:
		anchorless_multiplier = _anchorless.get_shield_recharge_multiplier(
			_contact.get_active_orb_id()
		)
	var total_amount := (
		balance.recharge_per_second
		* _speed_multiplier
		* anchorless_multiplier
		* maxf(0.0, delta)
	)
	var secondary_id := _find_weakest_other_section(section_id)
	if _distribution_ratio <= 0.0 or secondary_id < 0:
		_shield.restore(section_id, total_amount)
		recharge_distributed.emit(section_id, total_amount, -1, 0.0)
		return
	var secondary_amount := total_amount * _distribution_ratio
	var primary_amount := total_amount - secondary_amount
	_shield.restore(section_id, primary_amount)
	_shield.restore(secondary_id, secondary_amount)
	recharge_distributed.emit(section_id, primary_amount, secondary_id, secondary_amount)


func _find_weakest_other_section(excluded_section_id: int) -> int:
	if _shield is ShieldCoreShieldSystem:
		return (_shield as ShieldCoreShieldSystem).get_weakest_damaged_section(
			excluded_section_id
		)
	var best_id := -1
	var best_percent := INF
	for section_id: int in range(_shield.get_section_count()):
		if section_id == excluded_section_id:
			continue
		var percent := _shield.get_display_health_percent(section_id)
		if percent < 100.0 and percent < best_percent:
			best_percent = percent
			best_id = section_id
	return best_id
