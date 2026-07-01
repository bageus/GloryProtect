class_name ShieldCorePulseRuntime
extends RefCounted

var source: int
var section_id: int
var elapsed: float = 0.0


func _init(p_source: int, p_section_id: int) -> void:
	source = p_source
	section_id = p_section_id
