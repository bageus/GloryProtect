class_name BuildablePlacementPanelScene
extends BuildablePlacementPanel

@export_node_path("BuildablePlacementController") var controller_path: NodePath


func _ready() -> void:
	configure(get_node(controller_path) as BuildablePlacementController)
	super._ready()
