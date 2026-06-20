class_name BuildableSnapshot
extends RefCounted

var buildable_id: int
var type_id: int
var cell_index: int
var local_x: float


func _init(runtime: BuildableRuntime, new_local_x: float) -> void:
	buildable_id = runtime.buildable_id
	type_id = runtime.type_id
	cell_index = runtime.cell_index
	local_x = new_local_x
