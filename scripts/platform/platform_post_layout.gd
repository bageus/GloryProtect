extends Node

var _configured_scene_id: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	if scene_root.get_instance_id() == _configured_scene_id:
		return
	var panel := scene_root.get_node_or_null(
		"CanvasLayer/PrototypeHUD/CrewCommandPanel"
	) as CrewCommandPanel
	if panel == null:
		return
	_fix_panel_layout(panel)
	_configured_scene_id = scene_root.get_instance_id()


func _fix_panel_layout(panel: CrewCommandPanel) -> void:
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
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
	left_panel.anchor_top = 1.0
	left_panel.anchor_bottom = 1.0
	left_panel.offset_left = -620.0
	left_panel.offset_right = -180.0
	left_panel.offset_top = -90.0
	left_panel.offset_bottom = -5.0

	var right_panel: PanelContainer = side_panels[1]
	right_panel.anchor_left = 0.5
	right_panel.anchor_right = 0.5
	right_panel.anchor_top = 1.0
	right_panel.anchor_bottom = 1.0
	right_panel.offset_left = 180.0
	right_panel.offset_right = 620.0
	right_panel.offset_top = -90.0
	right_panel.offset_bottom = -5.0
