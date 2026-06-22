class_name RangedAttackComponent
extends Node

signal attack_started(target: HealthComponent)
signal projectile_launched(target: HealthComponent, start_position: Vector2, target_position: Vector2)
signal projectile_moved(position: Vector2)
signal attack_landed(target: HealthComponent, damage: int)
signal attack_finished

enum Phase {
	READY,
	WINDUP,
	PROJECTILE,
	COOLDOWN,
}

var profile: RangedAttackProfile
var owner_node: Node2D
var game_flow: GameFlowController
var phase: int = Phase.READY
var remaining_time: float = 0.0
var locked_target: HealthComponent
var projectile_position := Vector2.ZERO
var projectile_target_position := Vector2.ZERO


func configure(
	attack_profile: RangedAttackProfile,
	attack_owner: Node2D,
	flow: GameFlowController
) -> void:
	assert(attack_profile != null and attack_profile.is_valid())
	assert(attack_owner != null)
	assert(flow != null)
	profile = attack_profile
	owner_node = attack_owner
	game_flow = flow
	cancel()


func try_start(target: HealthComponent) -> bool:
	if not can_start() or target == null or not target.is_alive():
		return false
	var target_node: Node2D = target.get_parent() as Node2D
	if target_node == null or owner_node == null:
		return false
	if owner_node.global_position.distance_to(target_node.global_position) > profile.maximum_range:
		return false
	locked_target = target
	phase = Phase.WINDUP
	remaining_time = profile.windup_duration
	attack_started.emit(target)
	return true


func can_start() -> bool:
	return phase == Phase.READY and profile != null


func is_busy() -> bool:
	return phase != Phase.READY


func cancel() -> void:
	phase = Phase.READY
	remaining_time = 0.0
	locked_target = null
	projectile_position = Vector2.ZERO
	projectile_target_position = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if game_flow == null or not game_flow.is_world_simulation_active():
		return
	tick(maxf(0.0, delta))


func tick(delta: float) -> void:
	if phase == Phase.READY:
		return
	match phase:
		Phase.WINDUP:
			_tick_windup(delta)
		Phase.PROJECTILE:
			_tick_projectile(delta)
		Phase.COOLDOWN:
			_tick_cooldown(delta)


func _tick_windup(delta: float) -> void:
	remaining_time = maxf(0.0, remaining_time - delta)
	if remaining_time > 0.0:
		return
	if not is_instance_valid(locked_target):
		_finish_without_hit()
		return
	var target_node: Node2D = locked_target.get_parent() as Node2D
	if target_node == null:
		_finish_without_hit()
		return
	projectile_position = owner_node.global_position
	projectile_target_position = target_node.global_position
	phase = Phase.PROJECTILE
	projectile_launched.emit(
		locked_target,
		projectile_position,
		projectile_target_position
	)


func _tick_projectile(delta: float) -> void:
	var travel_distance: float = profile.projectile_speed * delta
	projectile_position = projectile_position.move_toward(
		projectile_target_position,
		travel_distance
	)
	projectile_moved.emit(projectile_position)
	if not projectile_position.is_equal_approx(projectile_target_position):
		return
	if is_instance_valid(locked_target) and locked_target.is_alive():
		locked_target.apply_damage(profile.damage)
		attack_landed.emit(locked_target, profile.damage)
	phase = Phase.COOLDOWN
	remaining_time = profile.cooldown_duration
	attack_finished.emit()


func _tick_cooldown(delta: float) -> void:
	remaining_time = maxf(0.0, remaining_time - delta)
	if remaining_time > 0.0:
		return
	phase = Phase.READY
	locked_target = null


func _finish_without_hit() -> void:
	phase = Phase.COOLDOWN
	remaining_time = profile.cooldown_duration
	attack_finished.emit()
