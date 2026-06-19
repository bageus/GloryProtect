class_name PrototypeHUD
extends Control

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("WindSystem") var wind_system_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("AnchorSystem") var anchor_system_path: NodePath
@export_node_path("PrototypeWorld") var world_path: NodePath
@export_node_path("PrototypeShieldSystem") var shield_system_path: NodePath

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _wind: WindSystem = get_node(wind_system_path)
@onready var _platform: PlatformController = get_node(platform_path)
@onready var _anchors: AnchorSystem = get_node(anchor_system_path)
@onready var _world: PrototypeWorld = get_node(world_path)
@onready var _shield: PrototypeShieldSystem = get_node(shield_system_path)

@onready var _state_label: Label = %StateLabel
@onready var _wind_label: Label = %WindLabel
@onready var _platform_label: Label = %PlatformLabel
@onready var _anchor_label: Label = %AnchorLabel
@onready var _contact_label: Label = %ContactLabel
@onready var _shield_label: Label = %ShieldLabel
@onready var _pause_label: Label = %PauseLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var state_text := _game_flow.get_state_name()
	if _game_flow.state == GameFlowController.RunState.START_DELAY:
		state_text += " (%.1f с)" % _game_flow.start_delay_remaining
	_state_label.text = "Состояние: %s" % state_text

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

	_anchor_label.text = "Якоря: %s | зона: %s" % [
		_anchors.get_state_summary(),
		"ДА" if _anchors.is_in_installation_zone() else "НЕТ",
	]

	_contact_label.text = "Энергетический контакт: %s" % (
		"УСТАНОВЛЕН" if _world.is_contact_active() else "НЕТ"
	)
	_shield_label.text = "Тестовая секция щита: %.1f%%" % _shield.get_health_percent()

	_pause_label.visible = _game_flow.state == GameFlowController.RunState.MANUAL_PAUSE
