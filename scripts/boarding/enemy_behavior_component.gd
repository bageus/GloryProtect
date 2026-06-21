class_name EnemyBehaviorComponent
extends Node

signal visual_state_changed(state_id: StringName)

enum TargetDomain {
	GROUND,
	AIR,
	DISTANT,
	OBJECT,
}

@export_enum("Ground", "Air", "Distant", "Object") var target_domain: int = TargetDomain.GROUND
@export var turret_targetable: bool = true
@export var counts_as_ground: bool = false
@export var counts_as_climbing: bool = false
@export var counts_as_boarded: bool = false

var enemy: BoardingEnemy
var game_flow: GameFlowController
var active: bool = false


func configure(
	owner_enemy: BoardingEnemy,
	flow: GameFlowController
) -> void:
	assert(owner_enemy != null, "EnemyBehaviorComponent requires enemy")
	assert(flow != null, "EnemyBehaviorComponent requires GameFlowController")
	enemy = owner_enemy
	game_flow = flow
	active = true
	_on_configured()


func stop() -> void:
	if not active:
		return
	active = false
	_on_stopped()


func is_targetable_by_turret() -> bool:
	return active and turret_targetable


func is_counted_as_ground() -> bool:
	return active and counts_as_ground


func is_counted_as_climbing() -> bool:
	return active and counts_as_climbing


func is_counted_as_boarded() -> bool:
	return active and counts_as_boarded


func publish_visual_state(state_id: StringName) -> void:
	visual_state_changed.emit(state_id)


func _physics_process(delta: float) -> void:
	if not active or game_flow == null:
		return
	if not game_flow.is_world_simulation_active():
		return
	_tick_behavior(maxf(0.0, delta))


func _on_configured() -> void:
	pass


func _on_stopped() -> void:
	pass


func _tick_behavior(_delta: float) -> void:
	pass
