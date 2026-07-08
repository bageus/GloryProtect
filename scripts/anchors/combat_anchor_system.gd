class_name CombatAnchorSystem
extends Node

signal upgrades_changed
signal periodic_pulse(anchor_id: int, damaged_enemy_count: int)
signal endpoint_pulse(anchor_id: int, damaged_enemy_count: int)
signal dropping_pulse(anchor_id: int, dropped_enemy_count: int)
signal enemy_dropped(anchor_id: int, enemy_id: int, source_id: StringName)
signal trap_triggered(
	anchor_id: int,
	world_position: Vector2,
	radius: float,
	damaged_enemy_count: int,
	source_id: StringName
)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("CombatAnchorHostSystem") var anchor_system_path: NodePath
@export_node_path("BoardingEnemyRegistry") var enemy_registry_path: NodePath
@export var balance: CombatAnchorBalance = preload(
	"res://resources/balance/combat_anchor_balance.tres"
)

var upgrades := CombatAnchorUpgradeRuntime.new()
var _periodic_elapsed := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _drop_elapsed := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _climbing_state: Dictionary[int, bool] = {}
var _rng := RandomNumberGenerator.new()

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _anchors: CombatAnchorHostSystem = get_node(anchor_system_path)
@onready var _enemies: BoardingEnemyRegistry = get_node(enemy_registry_path)


func _ready() -> void:
	assert(balance != null and balance.is_valid())
	process_physics_priority = -10
	_rng.randomize()
	_anchors.anchor_attached.connect(_on_anchor_attached)
	_anchors.anchor_detaching.connect(_on_anchor_detaching)
	_game_flow.run_state_changed.connect(_on_run_state_changed)
	_sync_anchor_modifiers()


func _physics_process(delta: float) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	_track_climbing_entries()
	var safe_delta: float = maxf(0.0, delta)
	_tick_periodic_electricity(safe_delta)
	_tick_dropping_pulses(safe_delta)


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
	_sync_anchor_modifiers()
	upgrades_changed.emit()
	return true


func reset_upgrade_runtime() -> void:
	upgrades.reset()
	_climbing_state.clear()
	for anchor_id: int in range(_periodic_elapsed.size()):
		_periodic_elapsed[anchor_id] = 0.0
		_drop_elapsed[anchor_id] = 0.0
	_anchors.reset_combat_anchor_modifiers()
	_sync_anchor_modifiers()
	upgrades_changed.emit()


func set_random_seed(value: int) -> void:
	_rng.seed = value


func get_periodic_interval() -> float:
	return balance.get_periodic_interval(upgrades.periodic_electric_advanced)


func get_drop_pulse_interval_for_tests() -> float:
	return balance.drop_pulse_interval_seconds


func get_endpoint_pulse_radius_for_tests() -> float:
	return balance.endpoint_pulse_radius


func get_trap_explosion_radius_for_tests() -> float:
	return balance.trap_attach_radius


func get_trap_knockback_distance_for_tests() -> float:
	return balance.trap_knockback_distance


func is_pair_install_fall_chance_enabled_for_tests() -> bool:
	return upgrades.strong_second_install_enabled


func _sync_anchor_modifiers() -> void:
	var overload_bonus: float = upgrades.overload_bonus_seconds
	if upgrades.has_strong_specialization():
		overload_bonus += balance.strong_overload_bonus_seconds
	var second_anchor_multiplier: float = 1.0
	if upgrades.strong_second_install_enabled:
		second_anchor_multiplier = balance.second_anchor_install_speed_multiplier
	var overload_threshold: int = (
		3 if upgrades.reinforced_wind_threshold_enabled else 2
	)
	_anchors.set_combat_anchor_modifiers(
		overload_bonus,
		upgrades.install_speed_bonus_ratio,
		second_anchor_multiplier,
		upgrades.instant_remove_all_enabled,
		overload_threshold,
		upgrades.second_winch_pair_enabled
	)


func _tick_periodic_electricity(delta: float) -> void:
	if not upgrades.periodic_electric_enabled:
		for anchor_id: int in range(_periodic_elapsed.size()):
			_periodic_elapsed[anchor_id] = 0.0
		return
	var interval: float = get_periodic_interval()
	for anchor_id: int in range(_periodic_elapsed.size()):
		if not _is_anchor_holding(anchor_id):
			_periodic_elapsed[anchor_id] = 0.0
			continue
		_periodic_elapsed[anchor_id] += delta
		while _periodic_elapsed[anchor_id] >= interval:
			_periodic_elapsed[anchor_id] -= interval
			var damaged: int = _damage_climbers_on_anchor(
				anchor_id,
				balance.periodic_damage,
				&"anchor_periodic_electric"
			)
			periodic_pulse.emit(anchor_id, damaged)


func _tick_dropping_pulses(delta: float) -> void:
	if not upgrades.electric_drop_enabled:
		for anchor_id: int in range(_drop_elapsed.size()):
			_drop_elapsed[anchor_id] = 0.0
		return
	var interval: float = balance.drop_pulse_interval_seconds
	for anchor_id: int in range(_drop_elapsed.size()):
		if not _is_anchor_holding(anchor_id):
			_drop_elapsed[anchor_id] = 0.0
			continue
		_drop_elapsed[anchor_id] += delta
		while _drop_elapsed[anchor_id] >= interval:
			_drop_elapsed[anchor_id] -= interval
			var dropped: int = _apply_dropping_pulse(anchor_id)
			dropping_pulse.emit(anchor_id, dropped)


func _track_climbing_entries() -> void:
	var next_state: Dictionary[int, bool] = {}
	for enemy: BoardingEnemy in _enemies.get_all_enemies():
		if enemy == null or not enemy.health.is_alive():
			continue
		var climbing: bool = enemy.is_counted_as_climbing()
		var was_climbing: bool = bool(_climbing_state.get(enemy.enemy_id, false))
		if (
			climbing
			and not was_climbing
			and _has_strong_entry_fall_chance()
			and _rng.randf() < balance.spontaneous_fall_chance
		):
			var anchor_id: int = enemy.get_selected_anchor_id()
			var enemy_id: int = enemy.enemy_id
			if enemy.knock_down_from_anchor(&"combat"):
				enemy_dropped.emit(anchor_id, enemy_id, &"anchor_strong_fall")
		next_state[enemy.enemy_id] = climbing
	_climbing_state = next_state


func _has_strong_entry_fall_chance() -> bool:
	return upgrades.strong_second_install_enabled or upgrades.strong_climber_fall_enabled


func _on_anchor_attached(anchor_id: int) -> void:
	_periodic_elapsed[anchor_id] = 0.0
	_drop_elapsed[anchor_id] = 0.0
	if upgrades.has_electric_specialization():
		_apply_electric_endpoint_pulse(anchor_id)
	if upgrades.has_trap_specialization():
		_apply_trap_explosion(anchor_id, &"anchor_trap_attach")


func _on_anchor_detaching(anchor_id: int) -> void:
	if upgrades.has_electric_specialization():
		_apply_electric_endpoint_pulse(anchor_id)
	if upgrades.has_trap_specialization():
		_apply_trap_explosion(anchor_id, &"anchor_trap_remove")
	_periodic_elapsed[anchor_id] = 0.0
	_drop_elapsed[anchor_id] = 0.0


func _apply_electric_endpoint_pulse(anchor_id: int) -> void:
	var snapshot: AnchorPathSnapshot = _anchors.get_path_snapshot(anchor_id)
	if snapshot == null:
		return
	var damaged_count: int = _damage_and_stun_ground_near(
		snapshot.ground_point,
		balance.endpoint_pulse_radius,
		balance.electric_pulse_damage,
		&"anchor_electric_endpoint"
	)
	endpoint_pulse.emit(anchor_id, damaged_count)


func _apply_dropping_pulse(anchor_id: int) -> int:
	var dropped_count: int = 0
	for enemy: BoardingEnemy in _enemies.get_all_enemies():
		if enemy == null or not enemy.health.is_alive():
			continue
		if not enemy.is_counted_as_climbing():
			continue
		if enemy.get_selected_anchor_id() != anchor_id:
			continue
		var enemy_id: int = enemy.enemy_id
		if _rng.randf() >= balance.electric_drop_chance:
			continue
		if enemy.knock_down_from_anchor(&"anchor_electric_drop"):
			dropped_count += 1
			enemy_dropped.emit(anchor_id, enemy_id, &"anchor_electric_drop")
	return dropped_count


func _apply_trap_explosion(anchor_id: int, source_id: StringName) -> void:
	var snapshot: AnchorPathSnapshot = _anchors.get_path_snapshot(anchor_id)
	if snapshot == null:
		return
	var radius: float = _get_trap_radius(source_id)
	var damage: int = _get_trap_damage(source_id)
	var damaged_count: int = _damage_and_knockback_ground_near(
		snapshot.ground_point,
		radius,
		damage,
		source_id
	)
	trap_triggered.emit(
		anchor_id,
		snapshot.ground_point,
		radius,
		damaged_count,
		source_id
	)


func _get_trap_radius(source_id: StringName) -> float:
	if source_id == &"anchor_trap_remove":
		return balance.trap_remove_radius
	return balance.trap_attach_radius


func _get_trap_damage(source_id: StringName) -> int:
	if source_id == &"anchor_trap_remove":
		return balance.trap_remove_damage
	return balance.trap_attach_damage


func _damage_climbers_on_anchor(
	anchor_id: int,
	amount: int,
	source_id: StringName
) -> int:
	var damaged_count: int = 0
	for enemy: BoardingEnemy in _enemies.get_all_enemies():
		if enemy == null or not enemy.health.is_alive():
			continue
		if not enemy.is_counted_as_climbing():
			continue
		if enemy.get_selected_anchor_id() != anchor_id:
			continue
		enemy.health.apply_damage(amount, source_id, self)
		damaged_count += 1
	return damaged_count


func _damage_and_stun_ground_near(
	world_position: Vector2,
	radius: float,
	amount: int,
	source_id: StringName
) -> int:
	var radius_squared: float = radius * radius
	var damaged_count: int = 0
	for enemy: BoardingEnemy in _enemies.get_all_enemies():
		if enemy == null or not enemy.health.is_alive():
			continue
		if not enemy.is_counted_as_ground():
			continue
		if world_position.distance_squared_to(enemy.global_position) > radius_squared:
			continue
		enemy.health.apply_damage(amount, source_id, self)
		damaged_count += 1
		if enemy.health.is_alive() and _rng.randf() < balance.electric_stun_chance:
			enemy.apply_stun(balance.electric_stun_seconds)
	return damaged_count


func _damage_and_knockback_ground_near(
	world_position: Vector2,
	radius: float,
	amount: int,
	source_id: StringName
) -> int:
	var radius_squared: float = radius * radius
	var damaged_count: int = 0
	for enemy: BoardingEnemy in _enemies.get_all_enemies():
		if enemy == null or not enemy.health.is_alive():
			continue
		if not enemy.is_counted_as_ground():
			continue
		if world_position.distance_squared_to(enemy.global_position) > radius_squared:
			continue
		enemy.health.apply_damage(amount, source_id, self)
		damaged_count += 1
		if enemy.health.is_alive():
			enemy.apply_ground_knockback(
				balance.trap_knockback_distance,
				world_position.x
			)
	return damaged_count


func _is_anchor_holding(anchor_id: int) -> bool:
	var state: int = _anchors.get_anchor_state(anchor_id)
	return state in [
		AnchorRuntime.State.ATTACHED,
		AnchorRuntime.State.OVERLOADED,
	]


func _on_run_state_changed(previous_state: int, new_state: int) -> void:
	if new_state != GameFlowController.RunState.START_DELAY:
		return
	if previous_state == GameFlowController.RunState.MANUAL_PAUSE:
		return
	reset_upgrade_runtime()
