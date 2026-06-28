class_name CrewAssignmentRuntime
extends RefCounted

enum State {
	ACTIVE,
	WAITING_FOR_ACTION,
	MOVING,
	DEAD,
}

var defender_id: int
var combat_role: int = CrewRole.Id.FREE_FIGHTER
var current_role: int = CrewRole.Id.FREE_FIGHTER
var current_station_id: int = -1
var target_role: int = CrewRole.Id.FREE_FIGHTER
var target_station_id: int = -1
var state: int = State.ACTIVE


func _init(new_defender_id: int) -> void:
	defender_id = new_defender_id
