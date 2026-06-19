class_name DefenderMovement
extends Node

signal destination_reached

@export_range(20.0, 600.0, 1.0) var move_speed: float = 180.0
@export_range(0.1, 10.0, 0.1) var arrival_epsilon: float = 1.0

var _target_x: float = 0.0
var _moving: bool = false

@onready var _actor: Node2D = get_parent() as Node2D


func configure(new_move_speed: float) -> void:
	move_speed = maxf(0.0, new_move_speed)


func move_to(target_x: float) -> void:
	_target_x = target_x
	if absf(_actor.position.x - _target_x) <= arrival_epsilon:
		_actor.position.x = _target_x
		_moving = false
		destination_reached.emit()
		return
	_moving = true


func stop() -> void:
	_moving = false
	_target_x = _actor.position.x


func teleport_to(target_x: float) -> void:
	_actor.position.x = target_x
	_target_x = target_x
	_moving = false


func is_moving() -> bool:
	return _moving


func get_target_x() -> float:
	return _target_x


func _physics_process(delta: float) -> void:
	if not _moving:
		return

	_actor.position.x = move_toward(
		_actor.position.x,
		_target_x,
		move_speed * delta
	)

	if absf(_actor.position.x - _target_x) > arrival_epsilon:
		return

	_actor.position.x = _target_x
	_moving = false
	destination_reached.emit()
