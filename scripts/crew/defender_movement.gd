class_name DefenderMovement
extends Node

signal destination_reached

@export_range(20.0, 600.0, 1.0) var move_speed: float = 180.0
@export_range(0.1, 10.0, 0.1) var arrival_epsilon: float = 1.0

var _target_x: float = 0.0
var _moving: bool = false
var _paused: bool = false
var _defender: Defender = null
var _movement_resolver: BoardingMovementResolver = null

@onready var _actor: Node2D = get_parent() as Node2D


func configure(new_move_speed: float) -> void:
	move_speed = maxf(0.0, new_move_speed)


func configure_collision(
	defender: Defender,
	movement_resolver: BoardingMovementResolver
) -> void:
	_defender = defender
	_movement_resolver = movement_resolver


func move_to(target_x: float) -> void:
	_target_x = target_x
	_paused = false
	if absf(_actor.position.x - _target_x) <= arrival_epsilon:
		_actor.position.x = _target_x
		_moving = false
		destination_reached.emit()
		return
	_moving = true


func pause() -> void:
	if _moving:
		_paused = true


func resume() -> void:
	if _moving:
		_paused = false


func stop() -> void:
	_moving = false
	_paused = false
	_target_x = _actor.position.x


func teleport_to(target_x: float) -> void:
	_actor.position.x = target_x
	_target_x = target_x
	_moving = false
	_paused = false


func is_moving() -> bool:
	return _moving


func is_paused() -> bool:
	return _paused


func get_target_x() -> float:
	return _target_x


func _physics_process(delta: float) -> void:
	if not _moving or _paused:
		return

	var desired_x: float = move_toward(
		_actor.position.x,
		_target_x,
		move_speed * delta
	)
	if _movement_resolver != null and _defender != null:
		desired_x = _movement_resolver.resolve_defender_platform_x(
			_defender,
			_actor.position.x,
			desired_x
		)
	_actor.position.x = desired_x

	if absf(_actor.position.x - _target_x) > arrival_epsilon:
		return
	_actor.position.x = _target_x
	_moving = false
	_paused = false
	destination_reached.emit()
