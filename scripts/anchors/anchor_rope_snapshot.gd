class_name AnchorRopeSnapshot
extends RefCounted

var anchor_id: int
var current_durability: float
var maximum_durability: float
var durability_ratio: float
var is_destroyed: bool


func _init(
	new_anchor_id: int,
	new_current_durability: float,
	new_maximum_durability: float
) -> void:
	anchor_id = new_anchor_id
	current_durability = new_current_durability
	maximum_durability = new_maximum_durability
	durability_ratio = 0.0
	if maximum_durability > 0.0:
		durability_ratio = clampf(
			current_durability / maximum_durability,
			0.0,
			1.0
		)
	is_destroyed = current_durability <= 0.0
