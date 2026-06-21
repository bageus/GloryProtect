class_name TurretRuntime
extends RefCounted

var buildable_id: int
var operator_id: int = -1
var target_enemy_id: int = -1
var shot_remaining: float = 0.0
var cooldown_remaining: float = 0.0
var firing: bool = false
var completed_shots: int = 0
var completed_volleys: int = 0
var volley_shots_remaining: int = 0


func _init(new_buildable_id: int) -> void:
	buildable_id = new_buildable_id


func begin_volley(shot_count: int) -> bool:
	if firing or volley_shots_remaining > 0 or shot_count <= 0:
		return false
	volley_shots_remaining = shot_count
	return true


func begin_shot(enemy_id: int, windup: float) -> void:
	target_enemy_id = enemy_id
	shot_remaining = maxf(0.0, windup)
	firing = true


func finish_shot(cooldown: float) -> bool:
	target_enemy_id = -1
	shot_remaining = 0.0
	firing = false
	completed_shots += 1
	volley_shots_remaining = maxi(0, volley_shots_remaining - 1)
	if volley_shots_remaining > 0:
		cooldown_remaining = 0.0
		return false
	completed_volleys += 1
	cooldown_remaining = maxf(0.0, cooldown)
	return true


func cancel_shot() -> void:
	target_enemy_id = -1
	shot_remaining = 0.0
	firing = false
	volley_shots_remaining = 0


func reset_combat_state() -> void:
	target_enemy_id = -1
	shot_remaining = 0.0
	cooldown_remaining = 0.0
	firing = false
	completed_shots = 0
	completed_volleys = 0
	volley_shots_remaining = 0


func is_volley_active() -> bool:
	return volley_shots_remaining > 0


func is_next_shot_fifth() -> bool:
	return (completed_shots + 1) % 5 == 0


func is_next_volley_fifth() -> bool:
	return (completed_volleys + 1) % 5 == 0
