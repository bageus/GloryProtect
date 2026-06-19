class_name ShieldDebugInput
extends Node

signal selected_section_changed(section_id: int)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("ShieldSystem") var shield_system_path: NodePath
@export var balance: ShieldBalance

var selected_section_id: int = 0

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _shield: ShieldSystem = get_node(shield_system_path)


func _ready() -> void:
	assert(balance != null, "ShieldDebugInput requires ShieldBalance")


func _unhandled_input(event: InputEvent) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	var section_id := _section_for_key(key_event.keycode)
	if section_id >= 0:
		_select_section(section_id)
	elif key_event.keycode == KEY_SPACE:
		_shield.apply_damage(selected_section_id, balance.debug_damage_amount)
	else:
		return

	get_viewport().set_input_as_handled()


func _select_section(section_id: int) -> void:
	if not _shield.is_valid_section(section_id):
		return
	selected_section_id = section_id
	selected_section_changed.emit(selected_section_id)


func _section_for_key(keycode: Key) -> int:
	match keycode:
		KEY_F1:
			return 0
		KEY_F2:
			return 1
		KEY_F3:
			return 2
		KEY_F4:
			return 3
		KEY_F5:
			return 4
		_:
			return -1
