class_name TurretUpgradeSystem
extends TurretSystem

@export var upgrade_balance: TurretUpgradeBalance = preload(
	"res://resources/balance/turret_specialization_balance.tres"
)
@export var combat_seed: int = 0

var upgrades := TurretUpgradeRuntime.new()
var _combat_resolver := TurretCombatResolver.new()


func _ready() -> void:
	super._ready()
	assert(upgrade_balance != null and upgrade_balance.is_valid())
	_combat_resolver.configure(upgrade_balance, combat_seed)
	_game_flow.run_state_changed.connect(_on_upgrade_run_state_changed)


func can_apply_upgrade_effect(effect: UpgradeEffectDefinition) -> bool:
	return upgrades.can_apply_effect(effect)


func apply_upgrade_effect(effect: UpgradeEffectDefinition) -> bool:
	if not can_apply_upgrade_effect(effect):
		return false
	match effect.effect_type:
		UpgradeEffectDefinition.EffectType.DOMAIN_SCALAR:
			return upgrades.apply_scalar(effect.target_id, effect.scalar_value)
		UpgradeEffectDefinition.EffectType.DOMAIN_FLAG:
			return upgrades.apply_flag(effect.target_id)
	return false


func reset_upgrade_runtime() -> void:
	upgrades.reset()
	for runtime: TurretRuntime in _runtimes.values():
		runtime.reset_combat_state()


func get_current_damage() -> int:
	return upgrades.get_damage(balance.turret_damage)


func get_current_cooldown() -> float:
	return upgrades.get_cooldown(balance.turret_shot_cooldown)


func get_current_range() -> float:
	return upgrades.get_range(balance.turret_range)


func get_specialization_id() -> StringName:
	return upgrades.specialization_id


func _update_runtime(runtime: TurretRuntime, delta: float) -> void:
	runtime.cooldown_remaining = maxf(0.0, runtime.cooldown_remaining - delta)
	var operator_id: int = _get_operational_operator_id(runtime.buildable_id)
	if operator_id < 0:
		_cancel_runtime_action(runtime)
		runtime.operator_id = -1
		return
	if runtime.operator_id >= 0 and runtime.operator_id != operator_id:
		_cancel_runtime_action(runtime)
	runtime.operator_id = operator_id

	if runtime.firing:
		runtime.shot_remaining = maxf(0.0, runtime.shot_remaining - delta)
		if runtime.shot_remaining <= 0.0:
			_complete_shot(runtime)
		return

	var assignment: CrewAssignmentRuntime = _roles.get_assignment(operator_id)
	if assignment == null or assignment.state != CrewAssignmentRuntime.State.ACTIVE:
		return
	if runtime.cooldown_remaining > 0.0:
		return

	var snapshot: BuildableSnapshot = _grid.get_snapshot(runtime.buildable_id)
	if snapshot == null:
		return
	var target: BoardingEnemy = _selector.get_nearest_target(
		_enemies,
		TurretGeometry.get_world_pivot(_platform, snapshot, balance),
		get_current_range()
	)
	if target == null:
		if runtime.is_volley_active():
			runtime.close_volley(get_current_cooldown())
		return
	if not runtime.is_volley_active():
		runtime.begin_volley(upgrades.get_shots_per_next_volley(runtime))
	_begin_shot(runtime, target)


func _complete_shot(runtime: TurretRuntime) -> void:
	var target_enemy_id: int = runtime.target_enemy_id
	var target: BoardingEnemy = _enemies.get_enemy(target_enemy_id)
	var hit: bool = false
	if target != null and _selector.is_still_targetable(target):
		var snapshot: BuildableSnapshot = _grid.get_snapshot(runtime.buildable_id)
		if snapshot != null:
			var origin: Vector2 = TurretGeometry.get_world_pivot(
				_platform,
				snapshot,
				balance
			)
			hit = _combat_resolver.resolve_shot(
				target,
				origin,
				get_current_range(),
				_enemies,
				upgrades,
				balance.turret_damage
			) > 0
	_roles.set_external_role_action_active(
		runtime.operator_id,
		CrewRole.Id.TURRET,
		false
	)
	runtime.finish_shot(get_current_cooldown())
	shot_completed.emit(runtime.buildable_id, target_enemy_id, hit)


func _cancel_runtime_action(runtime: TurretRuntime) -> void:
	if runtime.firing:
		_cancel_shot(runtime)
	elif runtime.is_volley_active():
		runtime.cancel_shot()


func _on_upgrade_run_state_changed(previous_state: int, new_state: int) -> void:
	if new_state != GameFlowController.RunState.START_DELAY:
		return
	if previous_state == GameFlowController.RunState.MANUAL_PAUSE:
		return
	reset_upgrade_runtime()
