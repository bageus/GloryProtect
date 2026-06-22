extends Node

const DRIVER_CELL_INDEX: int = 10

var _configured_scene_id: int = 0
var _active_grid: BuildableGrid
var _active_panel: CrewCommandPanel


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
	var grid := scene_root.get_node_or_null(
		"World/BuildableGrid"
	) as BuildableGrid
	var panel := scene_root.get_node_or_null(
		"CanvasLayer/PrototypeHUD/CrewCommandPanel"
	) as CrewCommandPanel
	if platform == null or grid == null or panel == null:
		return

	var visual := platform.get_node_or_null(
		"PlatformVisualController"
	) as PlatformVisualController
	if visual == null:
		return

	_align_driver_post(platform, visual)
	_compact_command_panel(panel)
	_connect_grid(grid, panel)
	_configured_scene_id = scene_root.get_instance_id()


func _align_driver_post(
	platform: PlatformController,
	visual: PlatformVisualController
) -> void:
	var offset: Vector2 = visual.driver_console_surface_offset
	offset.x = platform.get_cell_local_x(DRIVER_CELL_INDEX)
	visual.driver_console_surface_offset = offset
	visual.queue_redraw()


func _compact_command_panel(panel: CrewCommandPanel) -> void:
	panel.offset_top = -112.0
	panel.offset_bottom = 0.0

	var side_panels: Array[PanelContainer] = []
	for child: Node in panel.get_children():
		if child is PanelContainer:
			side_panels.append(child as PanelContainer)
	if side_panels.size() < 2:
		return

	var left_panel: PanelContainer = side_panels[0]
	left_panel.anchor_left = 0.5
	left_panel.anchor_right = 0.5
	left_panel.offset_left = -360.0
	left_panel.offset_right = -62.0
	left_panel.offset_top = -90.0
	left_panel.offset_bottom = -5.0

	var right_panel: PanelContainer = side_panels[1]
	right_panel.anchor_left = 0.5
	right_panel.anchor_right = 0.5
	right_panel.offset_left = 62.0
	right_panel.offset_right = 360.0
	right_panel.offset_top = -90.0
	right_panel.offset_bottom = -5.0

	for side_panel: PanelContainer in [left_panel, right_panel]:
		for node: Node in side_panel.find_children("*", "Button", true, false):
			var button := node as Button
			button.custom_minimum_size = Vector2(42.0, 70.0)
			button.add_theme_font_size_override("font_size", 10)
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _connect_grid(grid: BuildableGrid, panel: CrewCommandPanel) -> void:
	if _active_grid != null:
		var old_callable := Callable(self, "_on_buildable_placed")
		if _active_grid.buildable_placed.is_connected(old_callable):
			_active_grid.buildable_placed.disconnect(old_callable)
	_active_grid = grid
	_active_panel = panel
	var callback := Callable(self, "_on_buildable_placed")
	if not _active_grid.buildable_placed.is_connected(callback):
		_active_grid.buildable_placed.connect(callback)


func _on_buildable_placed(
	_buildable_id: int,
	type_id: int,
	cell_index: int
) -> void:
	if type_id != BuildableType.Id.TURRET or _active_panel == null:
		return
	var defender_id: int = int(
		_active_panel.call("_get_free_fighter_at_cell", cell_index)
	)
	if defender_id < 0:
		return
	_active_panel.call("_forget_free_cell", defender_id)
	var replacement_cell: int = int(
		_active_panel.call("_find_empty_free_cell")
	)
	if replacement_cell >= 0:
		_active_panel.call(
			"_assign_free_fighter_to_cell",
			defender_id,
			replacement_cell
		)
	_active_panel.call("_update_slots")
