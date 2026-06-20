class_name TurretVisualRuntime
extends RefCounted

var buildable_id: int
var target_enemy_id: int = -1
var shot_origin_local: Vector2 = Vector2.ZERO
var last_target_world: Vector2 = Vector2.ZERO
var tracer_remaining: float = 0.0
var flash_remaining: float = 0.0


func _init(new_buildable_id: int) -> void:
	buildable_id = new_buildable_id


func begin_target(
	enemy_id: int,
	origin_local: Vector2,
	target_world: Vector2
) -> void:
	target_enemy_id = enemy_id
	shot_origin_local = origin_local
	last_target_world = target_world


func update_target(target_world: Vector2) -> void:
	last_target_world = target_world


func resolve_shot(tracer_duration: float, flash_duration: float) -> void:
	tracer_remaining = maxf(0.0, tracer_duration)
	flash_remaining = maxf(0.0, flash_duration)
	target_enemy_id = -1


func cancel_target() -> void:
	target_enemy_id = -1
	last_target_world = Vector2.ZERO
	tracer_remaining = 0.0
	flash_remaining = 0.0


func tick(delta: float) -> void:
	tracer_remaining = maxf(0.0, tracer_remaining - delta)
	flash_remaining = maxf(0.0, flash_remaining - delta)
	if target_enemy_id < 0 and not is_effect_active():
		last_target_world = Vector2.ZERO


func is_effect_active() -> bool:
	return tracer_remaining > 0.0 or flash_remaining > 0.0
