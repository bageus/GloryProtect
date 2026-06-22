extends Node

func _ready() -> void:
	call_deferred("_install_visual")

func _install_visual() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		call_deferred("_install_visual")
		return
	var system: AnchorSystem = scene_root.get_node_or_null("World/AnchorSystem") as AnchorSystem
	if system == null:
		return
	var previous: Node = system.get_node_or_null("AnchorVisualController")
	if previous != null:
		previous.name = "AnchorVisualControllerLegacy"
		previous.queue_free()
	var visual := AnchorVisualActive.new()
	visual.name = "AnchorVisualController"
	system.add_child(visual)
	var flow: GameFlowController = scene_root.get_node("GameFlowController") as GameFlowController
	visual.configure(
		system.get("_store") as AnchorRuntimeStore,
		system.get("_geometry") as AnchorGeometry,
		system.balance,
		Callable(system, "is_operator_assigned"),
		Callable(flow, "is_world_simulation_active")
	)
