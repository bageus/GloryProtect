class_name OrbContactSystem
extends Node

signal contact_started(orb_id: int)
signal contact_ended(orb_id: int)
signal contact_changed(previous_orb_id: int, active_orb_id: int)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("GroundOrbRegistry") var registry_path: NodePath

var active_orb_id: int = -1

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _platform: PlatformController = get_node(platform_path)
@onready var _registry: GroundOrbRegistry = get_node(registry_path)


func _ready() -> void:
	process_physics_priority = -10


func _physics_process(_delta: float) -> void:
	var next_orb_id := -1
	if _game_flow.is_world_simulation_active():
		next_orb_id = _registry.get_contact_orb_at(_platform.position.x)
	_set_active_orb(next_orb_id)


func is_contact_active() -> bool:
	return active_orb_id >= 0


func get_active_orb_id() -> int:
	return active_orb_id


func get_active_section_id() -> int:
	if not is_contact_active():
		return -1
	return _registry.get_section_id(active_orb_id)


func _set_active_orb(next_orb_id: int) -> void:
	if next_orb_id == active_orb_id:
		return

	var previous_orb_id := active_orb_id
	if previous_orb_id >= 0:
		contact_ended.emit(previous_orb_id)

	active_orb_id = next_orb_id
	if active_orb_id >= 0:
		contact_started.emit(active_orb_id)

	contact_changed.emit(previous_orb_id, active_orb_id)
