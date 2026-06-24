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
var game_flow: GameFlowController


func _ready() -> void:
	game_flow = _resolve_game_flow()
	assert(
		game_flow != null,
		"StatusEffectComponent requires GameFlowController"
	)
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
	if game_flow == null or not game_flow.is_world_simulation_active():
		return
	_tick_poison(maxf(0.0, delta))


func _tick_poison(delta: float) -> void:
	poison_remaining = maxf(0.0, poison_remaining - delta)
	poison_tick_remaining = maxf(0.0, poison_tick_remaining - delta)
	if poison_tick_remaining <= 0.0:
		var active_profile: PoisonEffectProfile = poison_profile
		var active_stacks: int = poison_stacks
		var damage: int = active_profile.damage_per_tick * active_stacks
		var next_tick_interval: float = active_profile.tick_interval
		health.apply_damage(damage)
		poison_tick.emit(damage, active_stacks)
		if not health.is_alive():
			return
		poison_tick_remaining = next_tick_interval
	if poison_remaining <= 0.0:
		clear_poison()
	else:
		_emit_poison_changed()


func _resolve_game_flow() -> GameFlowController:
	var configured := get_node_or_null(game_flow_path) as GameFlowController
	if configured != null:
		return configured

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null
	return scene_root.get_node_or_null("GameFlowController") as GameFlowController


func _emit_poison_changed() -> void:
	poison_changed.emit(is_poisoned(), poison_stacks, poison_remaining)
