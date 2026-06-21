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
var rope_durability: float = 0.0
var attached_platform_x: float = 0.0
var target_orb_id: int = -1
var target_ground_point: Vector2 = Vector2.ZERO
var attached_orb_id: int = -1
var attached_ground_point: Vector2 = Vector2.ZERO


func _init(new_anchor_id: int, new_side: int) -> void:
	anchor_id = new_anchor_id
	side = new_side


func is_holding() -> bool:
	return state == State.ATTACHED or state == State.OVERLOADED


func has_target() -> bool:
	return target_orb_id >= 0


func has_attachment() -> bool:
	return attached_orb_id >= 0


func get_active_ground_point() -> Vector2:
	if has_attachment():
		return attached_ground_point
	return target_ground_point


func clear_ground_binding() -> void:
	target_orb_id = -1
	target_ground_point = Vector2.ZERO
	attached_orb_id = -1
	attached_ground_point = Vector2.ZERO
