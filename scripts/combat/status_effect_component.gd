class_name StatusEffectComponent
extends Node

signal poison_changed(active: bool, stacks: int, remaining_duration: float)
signal poison_tick(damage: int, stacks: int)

@export_node_path("HealthComponent") var health_path: NodePath
@export_node_path("GameFlowController") var game_flow_path: NodePath

var poison_profile: PoisonEffectProfile
var poison_stacks: int = 0
var poison_remaining: float = 0.0
var poison_tick_remaining: float = 0.0

@onready var health: HealthComponent = get_node(health_path)
@onready var game_flow: GameFlowController = get_node(game_flow_path)


func _ready() -> void:
	health.depleted.connect(clear_poison)


func apply_poison(profile: PoisonEffectProfile, stacks: int = 1) -> bool:
	if profile == null or not profile.is_valid() or stacks <= 0:
		return false
	if not health.is_alive():
		return false
	poison_profile = profile
	poison_stacks = mini(
		profile.maximum_stacks,
		maxi(1, poison_stacks + stacks)
	)
	poison_remaining = profile.duration
	if poison_tick_remaining <= 0.0:
		poison_tick_remaining = profile.tick_interval
	_emit_poison_changed()
	return true


func clear_poison() -> void:
	if poison_stacks <= 0:
		return
	poison_profile = null
	poison_stacks = 0
	poison_remaining = 0.0
	poison_tick_remaining = 0.0
	_emit_poison_changed()


func is_poisoned() -> bool:
	return poison_stacks > 0 and poison_profile != null


func _physics_process(delta: float) -> void:
	if not is_poisoned():
		return
	if not game_flow.is_world_simulation_active():
		return
	_tick_poison(maxf(0.0, delta))


func _tick_poison(delta: float) -> void:
	poison_remaining = maxf(0.0, poison_remaining - delta)
	poison_tick_remaining = maxf(0.0, poison_tick_remaining - delta)
	if poison_tick_remaining <= 0.0:
		var damage: int = poison_profile.damage_per_tick * poison_stacks
		health.apply_damage(damage)
		poison_tick.emit(damage, poison_stacks)
		poison_tick_remaining = poison_profile.tick_interval
		if not health.is_alive():
			return
	if poison_remaining <= 0.0:
		clear_poison()
	else:
		_emit_poison_changed()


func _emit_poison_changed() -> void:
	poison_changed.emit(is_poisoned(), poison_stacks, poison_remaining)
