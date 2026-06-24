class_name ShieldCoreSystem
extends Node

signal upgrades_changed
signal focused_retargeted(section_id: int, enemy_count: int)
signal surge_triggered(section_id: int, requested_rows: int, destroyed_rows: int)
signal completion_energy_shared(source_section_id: int, target_section_id: int, amount: float)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("ShieldCoreShieldSystem") var shield_system_path: NodePath
@export_node_path("ShieldCoreRechargeController") var recharge_controller_path: NodePath
@export_node_path("OrbContactSystem") var contact_system_path: NodePath
@export_node_path("ShieldCoreGroundOrbRegistry") var orb_registry_path: NodePath
@export_node_path("ShieldCoreStrategicWaveSystem") var strategic_wave_system_path: NodePath
@export var balance: ShieldCoreBalance = preload(
	"res://resources/balance/shield_core_balance.tres"
)

var upgrades := ShieldCoreUpgradeRuntime.new()
var _last_percents := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _shield: ShieldCoreShieldSystem = get_node(shield_system_path)
@onready var _recharge: ShieldCoreRechargeController = get_node(recharge_controller_path)
@onready var _contact: OrbContactSystem = get_node(contact_system_path)
@onready var _orbs: ShieldCoreGroundOrbRegistry = get_node(orb_registry_path)
@onready var _waves: ShieldCoreStrategicWaveSystem = get_node(strategic_wave_system_path)


func _ready() -> void:
	assert(balance != null and balance.is_valid())
	process_physics_priority = -15
	_rng.randomize()
	_initialize_percent_cache()
	_contact.contact_started.connect(_on_contact_started)
	_contact.contact_ended.connect(_on_contact_ended)
	_shield.section_changed.connect(_on_section_changed)
	_game_flow.run_state_changed.connect(_on_run_state_changed)
	_sync_modifiers()


func _physics_process(delta: float) -> void:
	if _game_flow.is_world_simulation_active():
		_shield.tick_emergency_reserve(maxf(0.0, delta))


func can_apply_upgrade_effect(effect: UpgradeEffectDefinition) -> bool:
	return upgrades.can_apply_effect(effect)


func apply_upgrade_effect(effect: UpgradeEffectDefinition) -> bool:
	if not can_apply_upgrade_effect(effect):
		return false
	var applied := false
	match effect.effect_type:
		UpgradeEffectDefinition.EffectType.DOMAIN_SCALAR:
			applied = upgrades.apply_scalar(effect.target_id, effect.scalar_value)
		UpgradeEffectDefinition.EffectType.DOMAIN_FLAG:
			applied = upgrades.apply_flag(effect.target_id)
	if not applied:
		return false
	_sync_modifiers()
	upgrades_changed.emit()
	return true


func reset_upgrade_runtime() -> void:
	upgrades.reset()
	_sync_modifiers()
	_initialize_percent_cache()
	upgrades_changed.emit()


func set_random_seed(value: int) -> void:
	_rng.seed = value
	_waves.set_effect_random_seed(value + 1)


func _sync_modifiers() -> void:
	_shield.set_capacity_multiplier(1.0 + upgrades.capacity_bonus_ratio)
	var speed_multiplier := 1.0 + upgrades.recharge_bonus_ratio
	if upgrades.has_focused_specialization():
		speed_multiplier *= 1.0 + balance.focused_recharge_bonus_ratio
	var distribution_ratio := 0.0
	if upgrades.has_distributed_specialization():
		distribution_ratio = balance.distributed_transfer_ratio
	_recharge.set_upgrade_modifiers(speed_multiplier, distribution_ratio)
	_orbs.set_contact_width_multiplier(1.0 + upgrades.contact_width_bonus_ratio)
	_shield.configure_emergency_reserve(
		upgrades.has_distributed_specialization(),
		balance.emergency_floor_percent,
		balance.emergency_hold_seconds
	)


func _on_contact_started(orb_id: int) -> void:
	var section_id := _orbs.get_section_id(orb_id)
	if upgrades.has_focused_specialization():
		var retargeted := _waves.retarget_fraction_from_section(
			section_id,
			balance.focused_retarget_ratio
		)
		focused_retargeted.emit(section_id, retargeted)
	if upgrades.has_surge_specialization():
		_trigger_surge(section_id)


func _on_contact_ended(orb_id: int) -> void:
	if upgrades.has_surge_specialization():
		_trigger_surge(_orbs.get_section_id(orb_id))


func _trigger_surge(section_id: int) -> void:
	var rows := balance.get_surge_row_count(_rng)
	var destroyed := _waves.destroy_nearest_rows(section_id, rows)
	surge_triggered.emit(section_id, rows, destroyed)


func _on_section_changed(
	section_id: int,
	_current_health: float,
	_max_health: float,
	percent: float
) -> void:
	if section_id < 0 or section_id >= _last_percents.size():
		return
	var previous := _last_percents[section_id]
	_last_percents[section_id] = percent
	if not upgrades.has_surge_specialization():
		return
	if previous >= 100.0 or percent < 100.0:
		return
	if _contact.get_active_section_id() != section_id:
		return
	var target_id := _shield.get_nearest_damaged_section(section_id)
	if target_id < 0:
		return
	var amount := (
		_shield.get_effective_max_health()
		* balance.surge_completion_restore_percent
		/ 100.0
	)
	_shield.restore(target_id, amount)
	completion_energy_shared.emit(section_id, target_id, amount)


func _initialize_percent_cache() -> void:
	_last_percents = PackedFloat32Array()
	_last_percents.resize(_shield.get_section_count())
	for section_id: int in range(_shield.get_section_count()):
		_last_percents[section_id] = _shield.get_display_health_percent(section_id)


func _on_run_state_changed(previous_state: int, new_state: int) -> void:
	if new_state != GameFlowController.RunState.START_DELAY:
		return
	if previous_state == GameFlowController.RunState.MANUAL_PAUSE:
		return
	reset_upgrade_runtime()
