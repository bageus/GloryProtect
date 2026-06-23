class_name AnchorlessControlSystem
extends Node

signal upgrades_changed
signal long_flight_restore_applied(section_id: int, amount: float)
signal contact_pulse_applied(source_id: StringName, damaged_enemy_count: int)
signal front_sweep_triggered(enemy_id: int)

const TARGET_ANY: int = 0
const TARGET_GROUND: int = 1
const TARGET_PLATFORM_OR_AIR: int = 2

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("WindSystem") var wind_system_path: NodePath
@export_node_path("OrbContactSystem") var contact_system_path: NodePath
@export_node_path("GroundOrbRegistry") var orb_registry_path: NodePath
@export_node_path("ShieldSystem") var shield_system_path: NodePath
@export_node_path("AnchorSystem") var anchor_system_path: NodePath
@export_node_path("BoardingEnemyRegistry") var enemy_registry_path: NodePath
@export var balance: AnchorlessControlBalance = preload(
	"res://resources/balance/anchorless_control_balance.tres"
)

var upgrades := AnchorlessControlUpgradeRuntime.new()
var _flight_seconds: float = 0.0
var _front_sweep_remaining: float = 0.0
var _last_anchor_points: Dictionary[int, Vector2] = {}

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _platform: PlatformController = get_node(platform_path)
@onready var _wind: WindSystem = get_node(wind_system_path)
@onready var _contact: OrbContactSystem = get_node(contact_system_path)
@onready var _orbs: GroundOrbRegistry = get_node(orb_registry_path)
@onready var _shield: ShieldSystem = get_node(shield_system_path)
@onready var _anchors: AnchorSystem = get_node(anchor_system_path)
@onready var _enemies: BoardingEnemyRegistry = get_node(enemy_registry_path)


func _ready() -> void:
	assert(balance != null and balance.is_valid())
	process_physics_priority = 5
	_contact.contact_started.connect(_on_contact_started)
	_contact.contact_ended.connect(_on_contact_ended)
	_anchors.anchor_attached.connect(_on_anchor_attached)
	_game_flow.run_state_changed.connect(_on_run_state_changed)
	_sync_motion_modifiers()


func _physics_process(delta: float) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	_front_sweep_remaining = maxf(0.0, _front_sweep_remaining - maxf(0.0, delta))
	if not _contact.is_contact_active():
		if absf(_platform.horizontal_velocity) >= balance.long_flight_minimum_speed:
			_flight_seconds += maxf(0.0, delta)
		else:
			_flight_seconds = 0.0
	if upgrades.front_sweep_enabled:
		_try_front_sweep()


func can_apply_upgrade_effect(effect: UpgradeEffectDefinition) -> bool:
	return upgrades.can_apply_effect(effect)


func apply_upgrade_effect(effect: UpgradeEffectDefinition) -> bool:
	if not can_apply_upgrade_effect(effect):
		return false
	var applied: bool = false
	match effect.effect_type:
		UpgradeEffectDefinition.EffectType.DOMAIN_SCALAR:
			applied = upgrades.apply_scalar(effect.target_id, effect.scalar_value)
		UpgradeEffectDefinition.EffectType.DOMAIN_FLAG:
			applied = upgrades.apply_flag(effect.target_id)
	if not applied:
		return false
	_sync_motion_modifiers()
	upgrades_changed.emit()
	return true


func reset_upgrade_runtime() -> void:
	upgrades.reset()
	_flight_seconds = 0.0
	_front_sweep_remaining = 0.0
	_last_anchor_points.clear()
	_platform.reset_anchorless_motion_modifiers()
	_wind.reset_anchorless_modifiers()
	_sync_motion_modifiers()
	upgrades_changed.emit()


func get_shield_recharge_multiplier(orb_id: int) -> float:
	if not upgrades.precise_recharge_enabled:
		return 1.0
	if orb_id < 0 or _contact.get_active_orb_id() != orb_id:
		return 1.0
	var center_half_width: float = (
		_orbs.get_contact_half_width()
		* balance.precise_center_half_width_ratio
	)
	var distance: float = absf(
		_platform.global_position.x - _orbs.get_world_x(orb_id)
	)
	if distance > center_half_width:
		return 1.0
	return 1.0 + balance.precise_recharge_bonus_ratio


func get_flight_seconds() -> float:
	return _flight_seconds


func get_last_anchor_point(side: int) -> Vector2:
	if not _last_anchor_points.has(side):
		return Vector2(INF, INF)
	return _last_anchor_points[side]


func _sync_motion_modifiers() -> void:
	var release_drag_bonus: float = upgrades.release_drag_bonus_ratio
	var acceleration_bonus: float = 0.0
	var max_speed_bonus: float = 0.0
	if upgrades.has_precise_specialization():
		release_drag_bonus += balance.precise_inertia_reduction_ratio
	if upgrades.has_speed_specialization():
		acceleration_bonus = balance.speed_acceleration_bonus_ratio
		max_speed_bonus = balance.speed_max_speed_bonus_ratio
	_platform.set_anchorless_motion_modifiers(
		upgrades.steering_force_bonus_ratio,
		release_drag_bonus,
		acceleration_bonus,
		max_speed_bonus
	)
	_wind.set_anchorless_modifiers(
		upgrades.wind_reduction_ratio,
		upgrades.automatic_steering_enabled
	)


func _on_contact_started(orb_id: int) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	if upgrades.has_speed_specialization():
		_platform.request_sharp_brake()
	if (
		upgrades.long_flight_restore_enabled
		and _flight_seconds >= balance.long_flight_required_seconds
	):
		var section_id: int = _orbs.get_section_id(orb_id)
		var amount: float = _shield.get_max_health() * balance.long_flight_restore_ratio
		_shield.restore(section_id, amount)
		long_flight_restore_applied.emit(section_id, amount)
	if upgrades.has_powerful_specialization():
		_apply_anchor_discharges()
	if upgrades.ground_core_enabled:
		_apply_ground_core_pulse(orb_id)
	if upgrades.platform_core_enabled:
		_apply_platform_core_pulse()
	_flight_seconds = 0.0


func _on_contact_ended(orb_id: int) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	if upgrades.ground_core_enabled:
		_apply_ground_core_pulse(orb_id)
	if upgrades.platform_core_enabled:
		_apply_platform_core_pulse()
	_flight_seconds = 0.0


func _on_anchor_attached(anchor_id: int) -> void:
	var snapshot: AnchorPathSnapshot = _anchors.get_path_snapshot(anchor_id)
	if snapshot == null:
		return
	_last_anchor_points[snapshot.side] = snapshot.ground_point


func _apply_anchor_discharges() -> void:
	var damaged_ids: Dictionary[int, bool] = {}
	for side: int in [AnchorRuntime.Side.LEFT, AnchorRuntime.Side.RIGHT]:
		if not _last_anchor_points.has(side):
			continue
		_damage_near(
			_last_anchor_points[side],
			balance.anchor_discharge_radius,
			balance.anchor_discharge_damage,
			TARGET_ANY,
			&"anchorless_anchor_discharge",
			damaged_ids
		)
	contact_pulse_applied.emit(&"anchorless_anchor_discharge", damaged_ids.size())


func _apply_ground_core_pulse(orb_id: int) -> void:
	if not _orbs.is_valid_orb(orb_id):
		return
	var damaged_ids: Dictionary[int, bool] = {}
	_damage_near(
		_orbs.get_orb_world_position(orb_id),
		balance.ground_core_radius,
		balance.core_pulse_damage,
		TARGET_GROUND,
		&"anchorless_ground_core",
		damaged_ids
	)
	contact_pulse_applied.emit(&"anchorless_ground_core", damaged_ids.size())


func _apply_platform_core_pulse() -> void:
	var damaged_ids: Dictionary[int, bool] = {}
	_damage_near(
		_platform.global_position,
		balance.platform_core_radius,
		balance.core_pulse_damage,
		TARGET_PLATFORM_OR_AIR,
		&"anchorless_platform_core",
		damaged_ids
	)
	contact_pulse_applied.emit(&"anchorless_platform_core", damaged_ids.size())


func _damage_near(
	world_position: Vector2,
	radius: float,
	amount: int,
	target_kind: int,
	source_id: StringName,
	damaged_ids: Dictionary[int, bool]
) -> void:
	var radius_squared: float = radius * radius
	for enemy: BoardingEnemy in _enemies.get_all_enemies():
		if enemy == null or not enemy.health.is_alive():
			continue
		if damaged_ids.has(enemy.enemy_id):
			continue
		if target_kind == TARGET_GROUND and not enemy.is_counted_as_ground():
			continue
		if (
			target_kind == TARGET_PLATFORM_OR_AIR
			and not _is_platform_or_air_target(enemy)
		):
			continue
		if world_position.distance_squared_to(enemy.global_position) > radius_squared:
			continue
		damaged_ids[enemy.enemy_id] = true
		enemy.health.apply_damage(amount, source_id, self)


func _is_platform_or_air_target(enemy: BoardingEnemy) -> bool:
	if enemy.is_counted_as_boarded():
		return true
	if enemy.behavior == null or not enemy.behavior.active:
		return false
	return (
		enemy.behavior.target_domain
		== EnemyBehaviorComponent.TargetDomain.AIR
	)


func _try_front_sweep() -> void:
	if _front_sweep_remaining > 0.0:
		return
	var velocity: float = _platform.horizontal_velocity
	if absf(velocity) < balance.front_sweep_minimum_speed:
		return
	var direction: float = signf(velocity)
	var leading_edge_x: float = (
		_platform.global_position.x
		+ direction * _platform.get_platform_width() * 0.5
	)
	var hit_count: int = 0
	for enemy: BoardingEnemy in _enemies.get_all_enemies():
		if enemy == null or not enemy.health.is_alive():
			continue
		if not enemy.is_counted_as_ground():
			continue
		var forward_distance: float = (
			enemy.global_position.x - leading_edge_x
		) * direction
		if forward_distance < 0.0 or forward_distance > balance.front_sweep_depth:
			continue
		if (
			absf(enemy.global_position.y - _platform.global_position.y)
			> balance.front_sweep_vertical_radius
		):
			continue
		var enemy_id: int = enemy.enemy_id
		enemy.health.apply_damage(
			enemy.health.current_health,
			&"anchorless_front_sweep",
			self
		)
		front_sweep_triggered.emit(enemy_id)
		hit_count += 1
	if hit_count > 0:
		_front_sweep_remaining = balance.front_sweep_cooldown


func _on_run_state_changed(previous_state: int, new_state: int) -> void:
	if new_state != GameFlowController.RunState.START_DELAY:
		return
	if previous_state == GameFlowController.RunState.MANUAL_PAUSE:
		return
	reset_upgrade_runtime()
