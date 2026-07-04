class_name CharacterAnimationController
extends RefCounted

signal state_changed(state_id: StringName)
signal frame_changed(frame_index: int)
signal animation_finished(state_id: StringName)

var _state_id: StringName = &""
var _frame_count: int = 1
var _frame_rate: float = 1.0
var _loop: bool = true
var _frame_index: int = 0
var _frame_elapsed: float = 0.0
var _finished: bool = false
var _facing_right: bool = true


func play(
	state_id: StringName,
	frame_count: int,
	frame_rate: float,
	loop: bool = true,
	restart: bool = false
) -> void:
	var safe_count: int = maxi(1, frame_count)
	var safe_rate: float = maxf(0.01, frame_rate)
	var changed: bool = (
		_state_id != state_id
		or _frame_count != safe_count
		or not is_equal_approx(_frame_rate, safe_rate)
		or _loop != loop
	)
	if not changed and not restart:
		return
	_state_id = state_id
	_frame_count = safe_count
	_frame_rate = safe_rate
	_loop = loop
	_frame_index = 0
	_frame_elapsed = 0.0
	_finished = false
	state_changed.emit(_state_id)
	frame_changed.emit(_frame_index)


func tick(delta: float) -> void:
	if _finished or _frame_count <= 1:
		return
	var frame_duration: float = 1.0 / _frame_rate
	_frame_elapsed += maxf(0.0, delta)
	while _frame_elapsed >= frame_duration and not _finished:
		_frame_elapsed -= frame_duration
		if _frame_index < _frame_count - 1:
			_set_frame_index(_frame_index + 1)
		elif _loop:
			_set_frame_index(0)
		else:
			_finished = true
			animation_finished.emit(_state_id)


func set_normalized_progress(progress: float) -> void:
	var safe_progress: float = clampf(progress, 0.0, 1.0)
	var next_frame: int = roundi(safe_progress * float(_frame_count))
	_set_frame_index(next_frame)
	_frame_elapsed = 0.0
	_finished = not _loop and safe_progress >= 1.0


func set_facing_right(facing_right: bool) -> void:
	_facing_right = facing_right


func face_delta(delta_x: float, epsilon: float = 0.01) -> void:
	if absf(delta_x) <= epsilon:
		return
	_facing_right = delta_x > 0.0


func get_state_id() -> StringName:
	return _state_id


func get_frame_index() -> int:
	return _frame_index


func get_frame_count() -> int:
	return _frame_count


func is_finished() -> bool:
	return _finished


func is_facing_right() -> bool:
	return _facing_right


func _set_frame_index(frame_index: int) -> void:
	var safe_index: int = clampi(frame_index, 0, _frame_count - 1)
	if _frame_index == safe_index:
		return
	_frame_index = safe_index
	frame_changed.emit(_frame_index)
