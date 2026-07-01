class_name BuildablePlacementPanelScene
extends BuildablePlacementPanel

@export_node_path("BuildablePlacementController") var controller_path: NodePath
@export var use_unified_context: bool = false


func _ready() -> void:
	configure(get_node(controller_path) as BuildablePlacementController)
	if use_unified_context:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)
		return
	super._ready()


func _refresh() -> void:
	super._refresh()
	if not visible:
		return
	var has_object: bool = _controller.get_selected_buildable_id() >= 0
	_move_button.visible = has_object
	_move_button.disabled = (
		not _controller.are_commands_enabled()
		or not has_object
	)
