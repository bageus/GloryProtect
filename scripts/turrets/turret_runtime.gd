class_name TurretRuntime
extends RefCounted

var buildable_id: int
var operator_id: int = -1
var target_enemy_id: int = -1
var shot_remaining: float = 0.0
var cooldown_remaining: float = 0.0
var firing: bool = false
var completed_volleys: int = 0


func _init(new_buildable_id: int) -> void:
	buildable_id = new_buildable_id


func begin_shot(enemy_id: int, windup: float) -> void:
	target_enemy_id = enemy_id
	shot_remaining = maxf(0.0, windup)
	firing = true


func finish_shot(cooldown: float) -> void:
	target_enemy_id = -1
	shot_remaining = 0.0
	cooldown_remaining = maxf(0.0, cooldown)
	firing = false
	completed_volleys += 1


func cancel_shot() -> void:
	target_enemy_id = -1
	shot_remaining = 0.0
	firing = false


func is_fifth_volley() -> bool:
	return (completed_volleys + 1) % 5 == 0
