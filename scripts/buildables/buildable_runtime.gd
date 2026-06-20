class_name BuildableRuntime
extends RefCounted

var buildable_id: int
var type_id: int
var cell_index: int


func _init(new_buildable_id: int, new_type_id: int, new_cell_index: int) -> void:
	buildable_id = new_buildable_id
	type_id = new_type_id
	cell_index = new_cell_index
