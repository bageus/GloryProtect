class_name MedicProtectiveHealingController
extends Node

signal chain_heal_applied(
	primary_target_id: int,
	secondary_target_id: int,
	restored_amount: int
)

@export_node_path("CrewManager") var crew_manager_path: NodePath
@export_node_path("MedicalStationSystem") var medical_system_path: NodePath

@onready var _crew: CrewManager = get_node(crew_manager_path)
@onready var _medical: MedicalStationSystem = get_node(medical_system_path)


func _ready() -> void:
	_medical.segment_restored.connect(_on_segment_restored)


func _on_segment_restored(
	_medic_id: int,
	target_id: int,
	amount: int
) -> void:
	if amount <= 0:
		return
	var primary: Defender = _crew.get_defender(target_id)
	if primary == null or not primary.health.is_alive():
		return
	_apply_protective_effects(primary, amount)
	if not _medical.upgrades.chain_therapy_enabled:
		return
	var secondary: Defender = _choose_secondary_target(primary)
	if secondary == null:
		return
	var requested: int = maxi(
		1,
		floori(
			float(_medical.get_current_heal_amount())
			* _medical.upgrade_balance.chain_heal_ratio
		)
	)
	var previous_health: int = secondary.health.current_health
	secondary.health.heal(requested)
	var restored: int = secondary.health.current_health - previous_health
	if restored <= 0:
		return
	_apply_protective_effects(secondary, restored)
	chain_heal_applied.emit(primary.defender_id, secondary.defender_id, restored)


func _apply_protective_effects(target: Defender, restored_amount: int) -> void:
	if _medical.upgrades.protective_armor_enabled:
		target.durability.add_temporary_armor(
			restored_amount
			* _medical.upgrade_balance.armor_per_healed_segment
		)
	if (
		_medical.upgrades.protective_full_guard_enabled
		and target.health.current_health >= target.health.max_health
	):
		target.durability.set_next_hit_guard_available(true)


func _choose_secondary_target(primary: Defender) -> Defender:
	var selected: Defender = null
	var lowest_health: int = 2147483647
	var nearest_distance: float = INF
	for candidate: Defender in _crew.get_living_defenders():
		if candidate == primary:
			continue
		if candidate.health.current_health >= candidate.health.max_health:
			continue
		var distance: float = absf(
			candidate.global_position.x - primary.global_position.x
		)
		if candidate.health.current_health < lowest_health:
			selected = candidate
			lowest_health = candidate.health.current_health
			nearest_distance = distance
		elif (
			candidate.health.current_health == lowest_health
			and distance < nearest_distance
		):
			selected = candidate
			nearest_distance = distance
	return selected
