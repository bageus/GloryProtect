class_name WorldShakeController
extends Node

@export_node_path("AnchorSystem") var anchor_system_path: NodePath
@export_range(0.05, 1.0, 0.01) var duration: float = 0.24
@export_range(0.5, 20.0, 0.5) var amplitude: float = 5.0
@export_range(5.0, 80.0, 1.0) var frequency: float = 34.0

var _remaining: float = 0.0
var _elapsed: float = 0.0
var _base_transform := Transform2D.IDENTITY
var _trigger_count: int = 0

@onready var _anchors: AnchorSystem = get_node(anchor_system_path)


func _ready() -> void:
	_anchors.anchor_recovery_started.connect(_on_anchor_recovery_started)


func _process(delta: float) -> void:
	if _remaining <= 0.0:
		return
	var safe_delta: float = maxf(0.0, delta)
	_remaining = maxf(0.0, _remaining - safe_delta)
	_elapsed += safe_delta
	var progress: float = 1.0 - _remaining / maxf(duration, 0.01)
	var strength: float = amplitude * (1.0 - progress)
	var offset := Vector2(
		sin(_elapsed * frequency),
		cos(_elapsed * frequency * 1.37)
	) * strength
	var shaken := _base_transform
	shaken.origin += offset
	get_viewport().canvas_transform = shaken
	if _remaining <= 0.0:
		_restore_transform()


func trigger_tension_break() -> void:
	if _remaining <= 0.0:
		_base_transform = get_viewport().canvas_transform
	_remaining = duration
	_elapsed = 0.0
	_trigger_count += 1


func get_trigger_count() -> int:
	return _trigger_count


func is_shaking() -> bool:
	return _remaining > 0.0


func _exit_tree() -> void:
	_restore_transform()


func _restore_transform() -> void:
	if get_viewport() != null:
		get_viewport().canvas_transform = _base_transform
	_remaining = 0.0


func _on_anchor_recovery_started(
	_anchor_id: int,
	source: StringName,
	_removed_enemy_count: int
) -> void:
	if source == &"wind_overload":
		trigger_tension_break()
