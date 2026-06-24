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
var map_angle: float = 0.0
var map_distance: float = 1.0
var route_start_angle: float = 0.0
var route_start_distance: float = 1.0
var route_target_angle: float = 0.0
var route_elapsed: float = 0.0
var mutation_cooldown_remaining: float = 0.0


func _init(
	new_group_id: int,
	new_section_id: int,
	new_enemy_count: int,
	new_travel_duration: float,
	new_lane_offset: float,
	section_count: int,
	mutation_cooldown: float
) -> void:
	group_id = new_group_id
	section_id = new_section_id
	enemy_count = maxi(1, new_enemy_count)
	initial_enemy_count = enemy_count
	travel_duration = maxf(0.01, new_travel_duration)
	lane_offset = new_lane_offset
	route_target_angle = get_section_angle(section_id, section_count)
	map_angle = wrapf(route_target_angle + lane_offset, 0.0, TAU)
	route_start_angle = map_angle
	mutation_cooldown_remaining = maxf(0.0, mutation_cooldown)


func replan_route(
	new_section_id: int,
	section_count: int,
	new_duration: float,
	mutation_cooldown: float
) -> void:
	section_id = new_section_id
	route_start_angle = map_angle
	route_start_distance = map_distance
	route_target_angle = get_section_angle(section_id, section_count)
	route_elapsed = 0.0
	travel_duration = maxf(0.01, new_duration)
	progress = 1.0 - map_distance
	state = State.TRAVELING
	impact_remaining = 0.0
	mutation_cooldown_remaining = maxf(0.0, mutation_cooldown)


static func get_section_angle(
	target_section_id: int,
	section_count: int
) -> float:
	if section_count <= 0:
		return 0.0
	return TAU * float(target_section_id) / float(section_count)
