extends Node

const DRIVER_CELL_INDEX: int = 10

var _configured_scene_id: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	if scene_root.get_instance_id() == _configured_scene_id:
		return
	var platform := scene_root.get_node_or_null(
		"World/Platform"
	) as PlatformController
	if platform == null:
		return
	var visual := platform.get_node_or_null(
		"PlatformVisualController"
	) as PlatformVisualController
	if visual == null:
		return
	var offset: Vector2 = visual.driver_console_surface_offset
	offset.x = platform.get_cell_local_x(DRIVER_CELL_INDEX)
	visual.driver_console_surface_offset = offset
	visual.queue_redraw()
	_configured_scene_id = scene_root.get_instance_id()
