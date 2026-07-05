class_name AnchorAssetPresentation
extends CombatAnchorVisualController

@export_node_path("CombatAnchorHostSystem") var anchor_system_path: NodePath
@export_node_path("CombatAnchorSystem") var combat_anchor_system_path: NodePath
@export_node_path("GameFlowController") var game_flow_path: NodePath

var _configured_from_scene: bool = false


func _ready() -> void:
	super._ready()
	z_as_relative = false
	z_index = maxi(z_index, minimum_z_index)
	call_deferred("_try_configure_from_scene")


func _process(delta: float) -> void:
	if not _configured_from_scene:
		_try_configure_from_scene()
	super._process(delta)


func is_configured_for_tests() -> bool:
	return _configured_from_scene


func uses_scene_mounted_anchor_renderer_for_tests() -> bool:
	return true


func _try_configure_from_scene() -> void:
	if _configured_from_scene:
		return
	var anchors: CombatAnchorHostSystem = get_node_or_null(
		anchor_system_path
	) as CombatAnchorHostSystem
	var combat: CombatAnchorSystem = get_node_or_null(
		combat_anchor_system_path
	) as CombatAnchorSystem
	var flow: GameFlowController = get_node_or_null(game_flow_path) as GameFlowController
	if anchors == null or combat == null or flow == null:
		return
	configure_combat(
		anchors._store,
		anchors._geometry,
		anchors.balance,
		Callable(anchors, "is_operator_assigned"),
		Callable(flow, "is_world_simulation_active"),
		anchors,
		combat
	)
	_configured_from_scene = true
	queue_redraw()
