class_name AnchorRopeSnapshot
extends RefCounted

var _anchor_id: int
var _current_durability: float
var _maximum_durability: float
var _durability_ratio: float
var _is_destroyed: bool

var anchor_id: int:
	get:
		return _anchor_id
var current_durability: float:
	get:
		return _current_durability
var maximum_durability: float:
	get:
		return _maximum_durability
var durability_ratio: float:
	get:
		return _durability_ratio
var is_destroyed: bool:
	get:
		return _is_destroyed


func _init(
	new_anchor_id: int,
	new_current_durability: float,
	new_maximum_durability: float
) -> void:
	_anchor_id = new_anchor_id
	_current_durability = new_current_durability
	_maximum_durability = new_maximum_durability
	_durability_ratio = 0.0
	if _maximum_durability > 0.0:
		_durability_ratio = clampf(
			_current_durability / _maximum_durability,
			0.0,
			1.0
		)
	_is_destroyed = _current_durability <= 0.0
