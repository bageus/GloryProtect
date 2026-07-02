class_name CombatAnchorSystem
extends Node

signal upgrades_changed
signal periodic_pulse(anchor_id: int, damaged_enemy_count: int)
signal endpoint_pulse(anchor_id: int, damaged_enemy_count: int)
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
	_tick_periodic_electricity(maxf(0.0, delta))


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
	_anchors.reset_combat_anchor_modifiers()
	_sync_anchor_modifiers()
	upgrades_changed.emit()


func set_random_seed(value: int) -> void:
	_rng.seed = value


func get_periodic_interval() -> float:
	return balance.get_periodic_interval(upgrades.periodic_electric_advanced)


func _sync_anchor_modifiers() -> void:
	var overload_bonus: float = upgrades.overload_bonus_seconds
	if upgrades.has_strong_specialization():
		overload_bonus += balance.strong_overload_bonus_seconds
	var second_anchor_multiplier: float = 1.0
	if upgrades.strong_second_install_enabled:
		second_anchor_multiplier = balance.second_anchor_install_speed_multiplier
	_anchors.set_combat_anchor_modifiers(
		overload_bonus,
		upgrades.install_speed_bonus_ratio,
		second_anchor_multiplier,
		upgrades.instant_remove_all_enabled
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
			and upgrades.strong_climber_fall_enabled
			and _rng.randf() < balance.spontaneous_fall_chance
		):
			var anchor_id: int = enemy.get_selected_anchor_id()
			var enemy_id: int = enemy.enemy_id
			if enemy.knock_down_from_anchor(&"combat"):
				enemy_dropped.emit(anchor_id, enemy_id, &"anchor_strong_fall")
		next_state[enemy.enemy_id] = climbing
	_climbing_state = next_state


func _on_anchor_attached(anchor_id: int) -> void:
	_periodic_elapsed[anchor_id] = 0.0
	if upgrades.has_electric_specialization():
		_apply_electric_endpoint_pulse(anchor_id)
	if upgrades.trap_attach_explosion_enabled:
		_apply_attach_trap(anchor_id)


func _on_anchor_detaching(anchor_id: int) -> void:
	if upgrades.has_electric_specialization():
		_apply_electric_endpoint_pulse(anchor_id)
	if upgrades.has_trap_specialization():
		_apply_remove_trap(anchor_id)
	_periodic_elapsed[anchor_id] = 0.0


func _apply_electric_endpoint_pulse(anchor_id: int) -> void:
	var snapshot: AnchorPathSnapshot = _anchors.get_path_snapshot(anchor_id)
	if snapshot == null:
		return
	var targets: Array[BoardingEnemy] = []
	var radius_squared: float = balance.endpoint_pulse_radius * balance.endpoint_pulse_radius
	for enemy: BoardingEnemy in _enemies.get_all_enemies():
		if enemy == null or not enemy.health.is_alive():
			continue
		var on_rope: bool = (
			enemy.is_counted_as_climbing()
			and enemy.get_selected_anchor_id() == anchor_id
		)
		var near_ground_endpoint: bool = (
			enemy.is_counted_as_ground()
			and snapshot.ground_point.distance_squared_to(enemy.global_position)
			<= radius_squared
		)
		if on_rope or near_ground_endpoint:
			targets.append(enemy)

	var damaged_count: int = 0
	for enemy: BoardingEnemy in targets:
		var was_climbing: bool = enemy.is_counted_as_climbing()
		var enemy_id: int = enemy.enemy_id
		enemy.health.apply_damage(
			balance.electric_pulse_damage,
			&"anchor_electric_endpoint",
			self
		)
		damaged_count += 1
		if not enemy.health.is_alive():
			continue
		if _rng.randf() < balance.electric_stun_chance:
			enemy.apply_stun(balance.electric_stun_seconds)
		if (
			was_climbing
			and upgrades.electric_drop_enabled
			and _rng.randf() < balance.electric_drop_chance
			and enemy.knock_down_from_anchor(&"combat")
		):
			enemy_dropped.emit(anchor_id, enemy_id, &"anchor_electric_drop")
	endpoint_pulse.emit(anchor_id, damaged_count)


func _apply_attach_trap(anchor_id: int) -> void:
	var snapshot: AnchorPathSnapshot = _anchors.get_path_snapshot(anchor_id)
	if snapshot == null:
		return
	var damaged_count: int = _damage_ground_near(
		snapshot.ground_point,
		balance.trap_attach_radius,
		balance.trap_attach_damage,
		&"anchor_trap_attach"
	)
	trap_triggered.emit(
		anchor_id,
		snapshot.ground_point,
		balance.trap_attach_radius,
		damaged_count,
		&"anchor_trap_attach"
	)


func _apply_remove_trap(anchor_id: int) -> void:
	var edge: Vector2 = _anchors.get_platform_attachment_world(anchor_id)
	var radius_squared: float = balance.trap_remove_radius * balance.trap_remove_radius
	var damaged_count: int = 0
	for enemy: BoardingEnemy in _enemies.get_boarded_enemies():
		if edge.distance_squared_to(enemy.global_position) > radius_squared:
			continue
		enemy.health.apply_damage(
			balance.trap_remove_damage,
			&"anchor_trap_remove",
			self
		)
		damaged_count += 1
		if enemy.health.is_alive():
			enemy.apply_platform_knockback(
				balance.trap_knockback_distance,
				edge.x
			)
	trap_triggered.emit(
		anchor_id,
		edge,
		balance.trap_remove_radius,
		damaged_count,
		&"anchor_trap_remove"
	)


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


func _damage_ground_near(
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
