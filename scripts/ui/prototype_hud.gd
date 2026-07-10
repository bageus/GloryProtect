class_name PrototypeHUD
extends Control

const ANCHOR_REMOVE_ALL_ACTION_ID := &"gp_anchor_remove_all"
const APP_SETTINGS_RUNTIME_PATH := NodePath("/root/AppSettingsRuntime")

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
@onready var _difficulty: RunDifficulty = get_node(run_difficulty_path)
@onready var _statistics: RunStatistics = get_node(run_statistics_path)
@onready var _wind: WindSystem = get_node(wind_system_path)
@onready var _platform: PlatformController = get_node(platform_path)
@onready var _anchors: AnchorSystem = get_node(anchor_system_path)
@onready var _crew_roles: CrewRoleManager = get_node(crew_role_manager_path)
@onready var _crew_input: CrewDebugInput = get_node(crew_debug_input_path)
@onready var _replacements: CrewReplacementController = get_node(
	crew_replacement_path
)
@onready var _economy: RunEconomy = get_node(run_economy_path)
@onready var _upgrades: UpgradeSystem = get_node(upgrade_system_path)
@onready var _buildable_inventory: BuildableInventory = get_node(
	buildable_inventory_path
)
@onready var _buildable_grid: BuildableGrid = get_node(buildable_grid_path)
@onready var _buildable_input: BuildableDebugInput = get_node(
	buildable_debug_input_path
)
@onready var _medical: MedicalStationSystem = get_node(medical_station_system_path)
@onready var _turrets: TurretSystem = get_node(turret_system_path)
@onready var _turret_input: TurretDebugInput = get_node(turret_input_path)
@onready var _orb_registry: GroundOrbRegistry = get_node(orb_registry_path)
@onready var _contact: OrbContactSystem = get_node(contact_system_path)
@onready var _shield: ShieldSystem = get_node(shield_system_path)
@onready var _shield_input: ShieldDebugInput = get_node(shield_debug_input_path)
@onready var _enemies: BoardingEnemyRegistry = get_node(enemy_registry_path)
@onready var _spawn: BoardingSpawnDirector = get_node(spawn_director_path)

@onready var _telemetry_panel: PanelContainer = $TelemetryPanel
@onready var _title_label: Label = $TelemetryPanel/Margin/VBox/Title
@onready var _state_label: Label = %StateLabel
@onready var _statistics_label: Label = %StatisticsLabel
@onready var _wind_label: Label = %WindLabel
@onready var _platform_label: Label = %PlatformLabel
@onready var _anchor_label: Label = %AnchorLabel
@onready var _crew_label: Label = %CrewLabel
@onready var _replacement_label: Label = %ReplacementLabel
@onready var _economy_label: Label = %EconomyLabel
@onready var _upgrade_label: Label = %UpgradeLabel
@onready var _buildable_label: Label = %BuildableLabel
@onready var _medical_label: Label = %MedicalLabel
@onready var _turret_label: Label = %TurretLabel
@onready var _boarding_label: Label = %BoardingLabel
@onready var _contact_label: Label = %ContactLabel
@onready var _shield_label: Label = %ShieldLabel
@onready var _target_label: Label = %TargetLabel
@onready var _pause_label: Label = %PauseLabel

var _placement: BuildablePlacementController
var _instant_anchor_remove_prompt: Label
var _app_settings: AppSettingsService


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_title_label.text = "GloryProtect — Prototype 2.0"
	_hide_telemetry_overlay()
	if not buildable_placement_controller_path.is_empty():
		_placement = get_node_or_null(
			buildable_placement_controller_path
		) as BuildablePlacementController
	_create_crew_command_panel()
	_create_instant_anchor_remove_prompt()
	_app_settings = get_node_or_null(APP_SETTINGS_RUNTIME_PATH) as AppSettingsService
	if _app_settings != null and not _app_settings.input_bindings_changed.is_connected(
		_update_instant_anchor_remove_prompt
	):
		_app_settings.input_bindings_changed.connect(
			_update_instant_anchor_remove_prompt
		)
	_update_instant_anchor_remove_prompt()


func _unhandled_input(_event: InputEvent) -> void:
	_hide_telemetry_overlay()


func _process(_delta: float) -> void:
	_hide_telemetry_overlay()
	_update_run_state()
	_update_statistics()
	_update_wind_and_platform()
	_update_anchors_crew_and_boarding()
	_update_buildables_medical_and_turrets()
	_update_contact_and_shield()
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
	return _telemetry_panel != null and _telemetry_panel.visible


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
		_get_anchor_remove_binding_text()
	)


func _get_anchor_remove_binding_text() -> String:
	if _app_settings != null:
		return _app_settings.get_binding_text(ANCHOR_REMOVE_ALL_ACTION_ID)
	return OS.get_keycode_string(KEY_R)


func _should_show_instant_anchor_remove_prompt() -> bool:
	return (
		_game_flow.is_world_simulation_active()
		and _anchors.is_instant_remove_all_enabled()
		and _anchors.get_active_path_count() > 0
	)


func _hide_telemetry_overlay() -> void:
	if _telemetry_panel == null:
		return
	_telemetry_panel.visible = false


func _update_run_state() -> void:
	var state_text: String = _game_flow.get_state_name()
	if _game_flow.state == GameFlowController.RunState.START_DELAY:
		state_text += " (%.1f с)" % _game_flow.start_delay_remaining
	elif _game_flow.state == GameFlowController.RunState.GAME_OVER:
		state_text += " | %s" % String(_game_flow.game_over_reason)
	_state_label.text = "Состояние: %s" % state_text


func _update_statistics() -> void:
	_statistics_label.text = "Результат: %s | физические убийства %d" % [
		_format_duration(_statistics.get_current_survival_seconds()),
		_statistics.get_physical_kills(),
	]


func _update_wind_and_platform() -> void:
	_wind_label.text = "Ветер: %s | сила %d | %.1f" % [
		_wind.get_direction_text(),
		_wind.strength_level,
		_wind.get_current_force(),
	]
	_platform_label.text = "Платформа: x %.1f | скорость %.1f | ввод %.1f" % [
		_platform.position.x,
		_platform.horizontal_velocity,
		_platform.steering_axis,
	]


func _update_anchors_crew_and_boarding() -> void:
	var installation_orb_id: int = _anchors.get_installation_orb_id()
	var zone_text: String = "НЕТ"
	if installation_orb_id >= 0:
		zone_text = "ШАР %d" % (installation_orb_id + 1)
	_anchor_label.text = "Якоря: %s | зона: %s" % [
		_anchors.get_state_summary(),
		zone_text,
	]
	_crew_label.text = "Экипаж: %s | выбран: %d" % [
		_crew_roles.get_summary(),
		_crew_input.get_selected_defender_id() + 1,
	]
	_replacement_label.text = "Замены: %s" % _replacements.get_summary()
	_economy_label.text = "Монеты забега: %d" % _economy.get_coins()
	_upgrade_label.text = "Карточки: куплено %d | следующая %d" % [
		_upgrades.get_completed_purchase_count(),
		_upgrades.get_current_cost(),
	]
	_boarding_label.text = (
		"Абордаж: %s | всего %d | земля %d/%d | спавн %.2f с"
		+ " | сложность %.1f%% | время %.1f с"
	) % [
		_enemies.get_state_summary(),
		_enemies.get_active_count(),
		_enemies.get_ground_count(),
		_spawn.get_current_ground_limit(),
		_spawn.get_current_spawn_interval(),
		_difficulty.get_percent(),
		_difficulty.get_elapsed_seconds(),
	]


func _update_buildables_medical_and_turrets() -> void:
	var placement_summary := _buildable_input.get_summary()
	var turret_selection_summary := _turret_input.get_summary()
	if _placement != null:
		placement_summary = _placement.get_summary()
		var selected_turret := _placement.get_selected_turret_id()
		turret_selection_summary = (
			"турель не выбрана"
			if selected_turret < 0
			else "выбрана T%d" % (selected_turret + 1)
		)
	_buildable_label.text = "Объекты: %s | %s | %s" % [
		_buildable_inventory.get_summary(),
		_buildable_grid.get_summary(),
		placement_summary,
	]
	_medical_label.text = "Лечение: %s" % _medical.get_summary()
	_turret_label.text = "Турели: %s | %s" % [
		_turrets.get_summary(),
		turret_selection_summary,
	]


func _update_contact_and_shield() -> void:
	var contact_text: String = "НЕТ"
	if _contact.is_contact_active():
		contact_text = "ШАР %d / СЕКЦИЯ %d" % [
			_contact.get_active_orb_id() + 1,
			_contact.get_active_section_id() + 1,
		]
	_contact_label.text = "Энергетический контакт: %s" % contact_text
	_shield_label.text = "Щит: %s | тестовая секция: %d" % [
		_shield.get_state_summary(),
		_shield_input.selected_section_id + 1,
	]
	_target_label.text = "Цели ≤50%%: %s" % _get_direction_targets_text()


func _get_direction_targets_text() -> String:
	var targets := PackedStringArray()
	for section_id: int in range(_shield.get_section_count()):
		if not _shield.needs_direction_indicator(section_id):
			continue
		var delta_x: float = (
			_orb_registry.get_world_x(section_id) - _platform.position.x
		)
		var direction: String = "ЗДЕСЬ"
		if delta_x < -_orb_registry.catalog.contact_half_width:
			direction = "←"
		elif delta_x > _orb_registry.catalog.contact_half_width:
			direction = "→"
		targets.append(
			"%s S%d %.0f%%" % [
				direction,
				section_id + 1,
				_shield.get_health_percent(section_id),
			]
		)
	if targets.is_empty():
		return "НЕТ"
	return "  ".join(targets)


func _format_duration(total_seconds: float) -> String:
	var rounded_seconds: int = maxi(0, floori(total_seconds))
	var minutes: int = floori(float(rounded_seconds) / 60.0)
	return "%02d:%02d" % [minutes, rounded_seconds % 60]
