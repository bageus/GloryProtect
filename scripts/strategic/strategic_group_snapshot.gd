class_name StrategicGroupSnapshot
extends RefCounted

var group_id: int
var section_id: int
var enemy_count: int
var initial_enemy_count: int
var progress: float
var lane_offset: float
var is_impacting: bool


func _init(runtime: StrategicGroupRuntime) -> void:
	group_id = runtime.group_id
	section_id = runtime.section_id
	enemy_count = runtime.enemy_count
	initial_enemy_count = runtime.initial_enemy_count
	progress = runtime.progress
	lane_offset = runtime.lane_offset
	is_impacting = runtime.state == StrategicGroupRuntime.State.IMPACTING
