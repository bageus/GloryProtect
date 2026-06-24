class_name BuildablePlacementDebugBridge
extends Node

@export_node_path("BuildablePlacementController") var controller_path: NodePath
@export_node_path("BuildableDebugInput") var buildable_debug_input_path: NodePath
@export_node_path("TurretDebugInput") var turret_debug_input_path: NodePath

@onready var _controller: BuildablePlacementController = get_node(controller_path)
@onready var _buildable_debug: BuildableDebugInput = get_node(
	buildable_debug_input_path
)
@onready var _turret_debug: TurretDebugInput = get_node(turret_debug_input_path)


func _ready() -> void:
	_controller.hovered_cell_changed.connect(_on_hovered_cell_changed)
	_controller.selected_turret_changed.connect(_on_selected_turret_changed)
	call_deferred("_sync_initial_state")


func _sync_initial_state() -> void:
	_on_hovered_cell_changed(_controller.get_hovered_cell_index())
	_on_selected_turret_changed(_controller.get_selected_turret_id())


func _on_hovered_cell_changed(cell_index: int) -> void:
	if cell_index >= 0:
		_buildable_debug.select_cell(cell_index)


func _on_selected_turret_changed(buildable_id: int) -> void:
	_turret_debug.call("_set_selected_turret", buildable_id)
