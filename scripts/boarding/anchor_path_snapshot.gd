class_name AnchorPathSnapshot
extends RefCounted

var anchor_id: int
var side: int
var orb_id: int
var ground_point: Vector2
var platform_point: Vector2


func _init(
	new_anchor_id: int,
	new_side: int,
	new_orb_id: int,
	new_ground_point: Vector2,
	new_platform_point: Vector2
) -> void:
	anchor_id = new_anchor_id
	side = new_side
	orb_id = new_orb_id
	ground_point = new_ground_point
	platform_point = new_platform_point
