class_name PrototypeHUD
extends Control

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("WindSystem") var wind_system_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("AnchorSystem") var anchor_system_path: NodePath
@export_node_path("CrewRoleManager") var crew_role_manager_path: NodePath
@export_node_path("CrewDebugInput") var crew_debug_input_path: NodePath
@export_node_path("CrewReplacementController") var crew_replacement_path: NodePath
@export_node_path("RunEconomy") var run_economy_path: NodePath
@export_node_path("GroundOrbRegistry") var orb_registry_path: NodePath
@export_node_path("OrbContactSystem") var contact_system_path: NodePath
@export_node_path("ShieldSystem") var shield_system_path: NodePath
@export_node_path("ShieldDebugInput") var shield_debug_input_path: NodePath
@export_node_path("BoardingEnemyRegistry") var enemy_registry_path: NodePath

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _wind: WindSystem = get_node(wind_system_path)
@onready var _platform: PlatformController = get_node(platform_path)
@onready var _anchors: AnchorSystem = get_node(anchor_system_path)
@onready var _crew_roles: CrewRoleManager = get_node(crew_role_manager_path)
@onready var _crew_input: CrewDebugInput = get_node(crew_debug_input_path)
@onready var _replacements: CrewReplacementController = get_node(
	crew_replacement_path
)
@onready var _economy: RunEconomy = get_node(run_economy_path)
@onready var _orb_registry: GroundOrbRegistry = get_node(orb_registry_path)
@onready var _contact: OrbContactSystem = get_node(contact_system_path)
@onready var _shield: ShieldSystem = get_node(shield_system_path)
@onready var _shield_input: ShieldDebugInput = get_node(shield_debug_input_path)
@onready var _enemies: BoardingEnemyRegistry = get_node(enemy_registry_path)

@onready var _state_label: Label = %StateLabel
@onready var _wind_label: Label = %WindLabel
@onready var _platform_label: Label = %PlatformLabel
@onready var _anchor_label: Label = %AnchorLabel
@onready var _crew_label: Label = %CrewLabel
@onready var _replacement_label: Label = %ReplacementLabel
@onready var _economy_label: Label = %EconomyLabel
@onready var _boarding_label: Label = %BoardingLabel
@onready var _contact_label: Label = %ContactLabel
@onready var _shield_label: Label = %ShieldLabel
@onready var _target_label: Label = %TargetLabel
@onready var _pause_label: Label = %PauseLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	_update_run_state()
	_update_wind_and_platform()
	_update_anchors_crew_and_boarding()
	_update_contact_and_shield()
	_pause_label.visible = (
		_game_flow.state == GameFlowController.RunState.MANUAL_PAUSE
	)


func _update_run_state() -> void:
	var state_text: String = _game_flow.get_state_name()
	if _game_flow.state == GameFlowController.RunState.START_DELAY:
		state_text += " (%.1f с)" % _game_flow.start_delay_remaining
	elif _game_flow.state == GameFlowController.RunState.GAME_OVER:
		state_text += " | %s" % String(_game_flow.game_over_reason)
	_state_label.text = "Состояние: %s" % state_text


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
		_crew_input.selected_defender_id + 1,
	]
	_replacement_label.text = "Замены: %s" % _replacements.get_summary()
	_economy_label.text = "Монеты забега: %d" % _economy.get_coins()
	_boarding_label.text = "Абордаж: %s | всего %d" % [
		_enemies.get_state_summary(),
		_enemies.get_active_count(),
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
