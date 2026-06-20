class_name ShieldCriticalAlertController
extends Node

signal critical_alert_raised(section_ids: Array[int])

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("ShieldSystem") var shield_system_path: NodePath

var _pending_section_ids: Array[int] = []
var _flush_scheduled: bool = false

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _shield: ShieldSystem = get_node(shield_system_path)


func _ready() -> void:
	_shield.section_entered_critical.connect(_on_section_entered_critical)
	_game_flow.run_state_changed.connect(_on_run_state_changed)


func _on_section_entered_critical(section_id: int) -> void:
	if _game_flow.state != GameFlowController.RunState.RUNNING:
		return
	if not _pending_section_ids.has(section_id):
		_pending_section_ids.append(section_id)
	if _flush_scheduled:
		return
	_flush_scheduled = true
	call_deferred("_flush_pending_alert")


func _flush_pending_alert() -> void:
	_flush_scheduled = false
	if _pending_section_ids.is_empty():
		return
	_pending_section_ids.sort()
	var emitted_ids: Array[int] = _pending_section_ids.duplicate()
	_pending_section_ids.clear()
	critical_alert_raised.emit(emitted_ids)


func _on_run_state_changed(_previous_state: int, new_state: int) -> void:
	if new_state == GameFlowController.RunState.RUNNING:
		return
	_pending_section_ids.clear()
	_flush_scheduled = false
