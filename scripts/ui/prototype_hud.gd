class_name PrototypeHUD
extends Control

const ANCHOR_REMOVE_ALL_ACTION_ID := &"gp_anchor_remove_all"

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("RunDifficulty") var run_difficulty_path: NodePath
@export_node_path("RunStatistics") var run_statistics_path: NodePath
@export_node_path("WindSystem") var wind_system_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("AnchorSystem") var anchor_system_path: NodePath
@export_node_path("CrewRoleManager") var crew_role_manager_path: NodePath
@export_node_path("CrewDebugInput") var crew_debug_input_path: NodePath
@export_node_path("CrewReplacementController") var crew_replacement_path: NodePath
@export_node_path("RunEconomy") var run_economy_path: NodePath
@export_node_path("UpgradeSystem") var upgrade_system_path: NodePath
@export_node_path("BuildableInventory") var buildable_inventory_path: NodePath
@export_node_path("BuildableGrid") var buildable_grid_path: NodePath
@export_node_path("BuildableDebugInput") var buildable_debug_input_path: NodePath
@export_node_path("BuildablePlacementController") var buildable_placement_controller_path: NodePath
@export_node_path("MedicalStationSystem") var medical_station_system_path: NodePath
@export_node_path("TurretSystem") var turret_system_path: NodePath
@export_node_path("TurretDebugInput") var turret_debug_input_path: NodePath
@export_node_path("GroundOrbRegistry") var orb_registry_path: NodePath
@export_node_path("OrbContactSystem") var contact_system_path: NodePath
@export_node_path("ShieldSystem") var shield_system_path: NodePath
@export_node_path("ShieldDebugInput") var shield_debug_input_path: NodePath
@export_node_path("BoardingEnemyRegistry") var enemy_registry_path: NodePath
@export_node_path("BoardingSpawnDirector") var spawn_director_path: NodePath

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _anchors: AnchorSystem = get_node(anchor_system_path)
@onready var _crew_roles: CrewRoleManager = get_node(crew_role_manager_path)
@onready var _crew_input: CrewDebugInput = get_node(crew_debug_input_path)
@onready var _replacements: CrewReplacementController = get_node(
	crew_replacement_path
)
@onready var _buildable_grid: BuildableGrid = get_node(buildable_grid_path)
@onready var _pause_label: Label = %PauseLabel

var _placement: BuildablePlacementController
var _instant_anchor_remove_prompt: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hide_removed_telemetry_overlay()
	if not buildable_placement_controller_path.is_empty():
		_placement = get_node_or_null(
			buildable_placement_controller_path
		) as BuildablePlacementController
	_create_crew_command_panel()
	_create_instant_anchor_remove_prompt()
	if not AppSettings.input_bindings_changed.is_connected(
		_update_instant_anchor_remove_prompt
	):
		AppSettings.input_bindings_changed.connect(
			_update_instant_anchor_remove_prompt
		)
	_update_instant_anchor_remove_prompt()


func _unhandled_input(_event: InputEvent) -> void:
	_hide_removed_telemetry_overlay()


func _process(_delta: float) -> void:
	_hide_removed_telemetry_overlay()
	_update_instant_anchor_remove_prompt()
	_pause_label.visible = (
		_game_flow.state == GameFlowController.RunState.MANUAL_PAUSE
	)


func is_instant_anchor_remove_prompt_visible_for_tests() -> bool:
	return (
		_instant_anchor_remove_prompt != null
		and _instant_anchor_remove_prompt.visible
	)


func get_instant_anchor_remove_prompt_text_for_tests() -> String:
	if _instant_anchor_remove_prompt == null:
		return ""
	return _instant_anchor_remove_prompt.text


func is_telemetry_overlay_visible_for_tests() -> bool:
	var telemetry_panel := get_node_or_null("TelemetryPanel") as CanvasItem
	return telemetry_panel != null and telemetry_panel.visible


func _create_crew_command_panel() -> void:
	var panel := CrewCommandPanelPlacementAware.new()
	panel.name = "CrewCommandPanel"
	panel.configure(
		_game_flow,
		_crew_input,
		_crew_roles,
		_replacements,
		_buildable_grid
	)
	add_child(panel)


func _create_instant_anchor_remove_prompt() -> void:
	_instant_anchor_remove_prompt = Label.new()
	_instant_anchor_remove_prompt.name = "InstantAnchorRemovePrompt"
	_instant_anchor_remove_prompt.anchor_left = 0.5
	_instant_anchor_remove_prompt.anchor_right = 0.5
	_instant_anchor_remove_prompt.anchor_top = 1.0
	_instant_anchor_remove_prompt.anchor_bottom = 1.0
	_instant_anchor_remove_prompt.offset_left = -260.0
	_instant_anchor_remove_prompt.offset_right = 260.0
	_instant_anchor_remove_prompt.offset_top = -88.0
	_instant_anchor_remove_prompt.offset_bottom = -48.0
	_instant_anchor_remove_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instant_anchor_remove_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_instant_anchor_remove_prompt.add_theme_font_size_override("font_size", 20)
	_instant_anchor_remove_prompt.add_theme_color_override(
		"font_color",
		Color(1.0, 0.9, 0.42)
	)
	_instant_anchor_remove_prompt.add_theme_color_override(
		"font_outline_color",
		Color(0.03, 0.04, 0.08, 0.95)
	)
	_instant_anchor_remove_prompt.add_theme_constant_override("outline_size", 4)
	_instant_anchor_remove_prompt.visible = false
	_instant_anchor_remove_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_instant_anchor_remove_prompt)


func _update_instant_anchor_remove_prompt() -> void:
	if _instant_anchor_remove_prompt == null:
		return
	var should_show: bool = _should_show_instant_anchor_remove_prompt()
	_instant_anchor_remove_prompt.visible = should_show
	if not should_show:
		return
	_instant_anchor_remove_prompt.text = "[%s] быстро снять все тросы" % (
		AppSettings.get_binding_text(ANCHOR_REMOVE_ALL_ACTION_ID)
	)


func _should_show_instant_anchor_remove_prompt() -> bool:
	return (
		_game_flow.is_world_simulation_active()
		and _anchors.is_instant_remove_all_enabled()
		and _anchors.get_active_path_count() > 0
	)


func _hide_removed_telemetry_overlay() -> void:
	var telemetry_panel := get_node_or_null("TelemetryPanel") as CanvasItem
	if telemetry_panel == null:
		return
	telemetry_panel.visible = false
