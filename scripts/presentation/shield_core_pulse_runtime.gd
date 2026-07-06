class_name ShieldCorePulseRuntime
extends RefCounted

var source: int
var section_id: int
var elapsed: float = 0.0
var diameter_multiplier: float = 1.0


func _init(
	p_source: int,
	p_section_id: int,
	p_diameter_multiplier: float = 1.0
) -> void:
	source = p_source
	section_id = p_section_id
	diameter_multiplier = maxf(0.1, p_diameter_multiplier)
