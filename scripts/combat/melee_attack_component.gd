class_name MeleeAttackComponent
extends Node

enum Phase {
	READY,
	WINDUP,
	COOLDOWN,
}

signal attack_started(target: HealthComponent)
signal attack_landed(target: HealthComponent, damage: int)
signal attack_finished

var _damage: int = 1
var _windup_duration: float = 0.4
var _cooldown_duration: float = 0.7
var _phase: int = Phase.READY
var _remaining_time: float = 0.0
var _locked_target: HealthComponent = null
var _locked_damage: int = 1
var _locked_cooldown_duration: float = 0.7
var _follow_up_queued: bool = false
var _damage_source: Node = null


func configure(
	damage: int,
	windup_duration: float,
	cooldown_duration: float,
	damage_source: Node = null
) -> void:
	_damage = maxi(1, damage)
	_windup_duration = maxf(0.01, windup_duration)
	_cooldown_duration = maxf(0.01, cooldown_duration)
	_damage_source = damage_source


func get_damage() -> int:
	return _damage


func get_cooldown_duration() -> float:
	return _cooldown_duration


func tick(delta: float) -> void:
	if _phase == Phase.READY:
		return

	_remaining_time = maxf(0.0, _remaining_time - delta)
	if _remaining_time > 0.0:
		return

	match _phase:
		Phase.WINDUP:
			_resolve_locked_attack()
			if _consume_follow_up():
				return
			_phase = Phase.COOLDOWN
			_remaining_time = _locked_cooldown_duration
			attack_finished.emit()
		Phase.COOLDOWN:
			_phase = Phase.READY
			_locked_target = null


func try_start(target: HealthComponent) -> bool:
	if not can_start() or target == null or not target.is_alive():
		return false
	_locked_target = target
	_locked_damage = _damage
	_locked_cooldown_duration = _cooldown_duration
	_follow_up_queued = false
	_phase = Phase.WINDUP
	_remaining_time = _windup_duration
	attack_started.emit(target)
	return true


func queue_follow_up_same_target() -> bool:
	if _phase != Phase.WINDUP:
		return false
	if not is_instance_valid(_locked_target) or not _locked_target.is_alive():
		return false
	_follow_up_queued = true
	return true


func can_start() -> bool:
	return _phase == Phase.READY


func is_attacking() -> bool:
	return _phase == Phase.WINDUP


func is_busy() -> bool:
	return _phase != Phase.READY


func cancel() -> void:
	_phase = Phase.READY
	_remaining_time = 0.0
	_locked_target = null
	_follow_up_queued = false


func _resolve_locked_attack() -> void:
	if not is_instance_valid(_locked_target):
		return
	if not _locked_target.is_alive():
		return
	_locked_target.apply_damage(_locked_damage, &"melee", _damage_source)
	attack_landed.emit(_locked_target, _locked_damage)


func _consume_follow_up() -> bool:
	if not _follow_up_queued:
		return false
	_follow_up_queued = false
	if not is_instance_valid(_locked_target) or not _locked_target.is_alive():
		return false
	_phase = Phase.WINDUP
	_remaining_time = _windup_duration
	attack_started.emit(_locked_target)
	return true
