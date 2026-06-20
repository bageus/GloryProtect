class_name StrategicGroupRuntime
extends RefCounted

enum State {
	TRAVELING,
	IMPACTING,
}

var group_id: int
var section_id: int
var enemy_count: int
var initial_enemy_count: int
var progress: float = 0.0
var travel_duration: float
var lane_offset: float
var impact_remaining: float = 0.0
var state: State = State.TRAVELING


func _init(
	new_group_id: int,
	new_section_id: int,
	new_enemy_count: int,
	new_travel_duration: float,
	new_lane_offset: float
) -> void:
	group_id = new_group_id
	section_id = new_section_id
	enemy_count = maxi(1, new_enemy_count)
	initial_enemy_count = enemy_count
	travel_duration = maxf(0.01, new_travel_duration)
	lane_offset = new_lane_offset
