class_name AnchorRuntime
extends RefCounted

enum Side {
	LEFT,
	RIGHT,
}

enum State {
	STOWED,
	QUEUED,
	INSTALLING,
	ATTACHED,
	OVERLOADED,
	RETURNING,
}

var anchor_id: int
var side: int
var state: int = State.STOWED
var operation_progress: float = 0.0
var overload_progress: float = 0.0
var attached_platform_x: float = 0.0


func _init(new_anchor_id: int, new_side: int) -> void:
	anchor_id = new_anchor_id
	side = new_side


func is_holding() -> bool:
	return state == State.ATTACHED or state == State.OVERLOADED
