class_name CrewCommandPanelPlacementAware
extends CrewCommandPanelFixed


func _unhandled_input(event: InputEvent) -> void:
	var scene_root: Node = get_tree().current_scene
	if (
		scene_root != null
		and scene_root.has_node("BuildablePlacementController")
	):
		return
	super._unhandled_input(event)
