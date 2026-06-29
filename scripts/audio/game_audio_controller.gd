class_name GameAudioController
extends Node

signal sound_triggered(sound_id: StringName)

const SHIELD_CHARGE_STREAM: AudioStream = preload("res://audio/Energy_charge.ogg")
const SHIELD_ALERT_STREAM: AudioStream = preload("res://audio/allert shield.ogg")
const SHIELD_WAVE_STREAM: AudioStream = preload("res://audio/core_wave.ogg")
const DEFENDER_ATTACK_STREAM: AudioStream = preload("res://audio/defender_acctack.ogg")
const DEFENDER_DIE_STREAM: AudioStream = preload("res://audio/defender_die.ogg")
const HEALER_HEAL_STREAM: AudioStream = preload("res://audio/healer_heall.ogg")
const MONSTER_DIE_STREAM: AudioStream = preload("res://audio/monster_die.ogg")
const PLATFORM_MOVE_STREAM: AudioStream = preload("res://audio/moove platform.ogg")
const SHOOTER_ATTACK_STREAM: AudioStream = preload("res://audio/shooter_attack.ogg")
const PORTAL_STREAM: AudioStream = preload("res://audio/teleport_portal.ogg")
const TURRET_ATTACK_STREAM: AudioStream = preload("res://audio/turret_attack.ogg")
const WINCH_CONNECT_STREAM: AudioStream = preload("res://audio/winck_connect.ogg")
const WINCH_DISCONNECT_STREAM: AudioStream = preload("res://audio/winck_disconnect.ogg")

const SOUND_SHIELD_CHARGE: StringName = &"shield_charge"
const SOUND_SHIELD_ALERT: StringName = &"shield_alert"
const SOUND_SHIELD_WAVE: StringName = &"shield_wave"
const SOUND_DEFENDER_ATTACK: StringName = &"defender_attack"
const SOUND_DEFENDER_DIE: StringName = &"defender_die"
const SOUND_HEALER_HEAL: StringName = &"healer_heal"
const SOUND_MONSTER_DIE: StringName = &"monster_die"
const SOUND_PLATFORM_MOVE: StringName = &"platform_move"
const SOUND_SHOOTER_ATTACK: StringName = &"shooter_attack"
const SOUND_PORTAL: StringName = &"portal"
const SOUND_TURRET_ATTACK: StringName = &"turret_attack"
const SOUND_WINCH_CONNECT: StringName = &"winch_connect"
const SOUND_WINCH_DISCONNECT: StringName = &"winch_disconnect"

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("CrewManager") var crew_manager_path: NodePath
@export_node_path("CrewReplacementController") var replacement_controller_path: NodePath
@export_node_path("BoardingEnemyRegistry") var enemy_registry_path: NodePath
@export_node_path("MedicalStationSystem") var medical_system_path: NodePath
@export_node_path("TurretSystem") var turret_system_path: NodePath
@export_node_path("AnchorSystem") var anchor_system_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("OrbContactSystem") var contact_system_path: NodePath
@export_node_path("ShieldSystem") var shield_system_path: NodePath
@export_node_path("ShieldCoreSystem") var shield_core_system_path: NodePath

@export_group("Mix")
@export var enabled: bool = true
@export_range(-40.0, 6.0, 0.5) var one_shot_volume_db: float = -3.0
@export_range(-40.0, 6.0, 0.5) var loop_volume_db: float = -8.0
@export_range(0.1, 20.0, 0.1) var movement_velocity_threshold: float = 3.0

var _healing_active: bool = false
var _trigger_counts: Dictionary[StringName, int] = {}
var _loop_states: Dictionary[StringName, bool] = {}
var _loop_players: Dictionary[StringName, AudioStreamPlayer] = {}

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _crew: CrewManager = get_node(crew_manager_path)
@onready var _replacements: CrewReplacementController = get_node(replacement_controller_path)
@onready var _enemies: BoardingEnemyRegistry = get_node(enemy_registry_path)
@onready var _medical: MedicalStationSystem = get_node(medical_system_path)
@onready var _turrets: TurretSystem = get_node(turret_system_path)
@onready var _anchors: AnchorSystem = get_node(anchor_system_path)
@onready var _platform: PlatformController = get_node(platform_path)
@onready var _contact: OrbContactSystem = get_node(contact_system_path)
@onready var _shield: ShieldSystem = get_node(shield_system_path)
@onready var _shield_core: ShieldCoreSystem = get_node(shield_core_system_path)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_loop_players()
	_connect_system_signals()
	if not AppSettings.audio_settings_changed.is_connected(_on_audio_settings_changed):
		AppSettings.audio_settings_changed.connect(_on_audio_settings_changed)
	call_deferred("_connect_existing_defenders")
	_apply_audio_mix()
	_sync_loops()


func _process(_delta: float) -> void:
	_sync_loops()


func set_audio_enabled(value: bool) -> void:
	enabled = value
	_sync_loops()
	if not enabled:
		_stop_all_one_shots()


func get_trigger_count(sound_id: StringName) -> int:
	return int(_trigger_counts.get(sound_id, 0))


func is_loop_active(sound_id: StringName) -> bool:
	return bool(_loop_states.get(sound_id, false))


func get_effective_sound_volume(sound_id: StringName) -> float:
	return AppSettings.get_effects_volume() * AppSettings.get_sound_volume(sound_id)


func get_loaded_sound_ids() -> Array[StringName]:
	return [
		SOUND_SHIELD_CHARGE,
		SOUND_SHIELD_ALERT,
		SOUND_SHIELD_WAVE,
		SOUND_DEFENDER_ATTACK,
		SOUND_DEFENDER_DIE,
		SOUND_HEALER_HEAL,
		SOUND_MONSTER_DIE,
		SOUND_PLATFORM_MOVE,
		SOUND_SHOOTER_ATTACK,
		SOUND_PORTAL,
		SOUND_TURRET_ATTACK,
		SOUND_WINCH_CONNECT,
		SOUND_WINCH_DISCONNECT,
	]


func refresh_audio_state_for_tests() -> void:
	_apply_audio_mix()
	_sync_loops()


func _create_loop_players() -> void:
	_register_loop(SOUND_SHIELD_CHARGE, SHIELD_CHARGE_STREAM)
	_register_loop(SOUND_SHIELD_ALERT, SHIELD_ALERT_STREAM)
	_register_loop(SOUND_HEALER_HEAL, HEALER_HEAL_STREAM)
	_register_loop(SOUND_PLATFORM_MOVE, PLATFORM_MOVE_STREAM)


func _register_loop(sound_id: StringName, source: AudioStream) -> void:
	var player := AudioStreamPlayer.new()
	player.name = "Loop%s" % String(sound_id).to_pascal_case()
	player.stream = _make_loop_stream(source)
	player.bus = String(AppSettings.EFFECTS_BUS)
	player.volume_db = _get_sound_volume_db(sound_id, loop_volume_db)
	add_child(player)
	_loop_players[sound_id] = player
	_loop_states[sound_id] = false


func _make_loop_stream(source: AudioStream) -> AudioStream:
	var result: AudioStream = source.duplicate(true) as AudioStream
	if result is AudioStreamOggVorbis:
		(result as AudioStreamOggVorbis).loop = true
	return result


func _connect_system_signals() -> void:
	_crew.defender_spawned.connect(_on_defender_spawned)
	_crew.defender_replaced.connect(_on_defender_spawned)
	_crew.defender_died.connect(_on_defender_died)
	_enemies.enemy_removed.connect(_on_enemy_removed)
	_replacements.replacement_completed.connect(_on_replacement_completed)
	_medical.healing_started.connect(_on_healing_started)
	_medical.healing_stopped.connect(_on_healing_stopped)
	_turrets.shot_started.connect(_on_turret_shot_started)
	_anchors.anchor_attached.connect(_on_anchor_attached)
	_anchors.anchor_removed.connect(_on_anchor_removed)
	_anchors.anchor_broken.connect(_on_anchor_broken)
	_shield_core.completion_energy_shared.connect(_on_completion_energy_shared)
	_game_flow.run_state_changed.connect(_on_run_state_changed)


func _connect_existing_defenders() -> void:
	for defender: Defender in _crew.get_all_defenders():
		_connect_defender(defender)


func _connect_defender(defender: Defender) -> void:
	if defender == null:
		return
	if not defender.melee.attack_started.is_connected(
		_on_defender_melee_attack_started
	):
		defender.melee.attack_started.connect(
			_on_defender_melee_attack_started
		)
	if (
		defender.ranged != null
		and not defender.ranged.projectile_launched.is_connected(
			_on_shooter_projectile_launched
		)
	):
		defender.ranged.projectile_launched.connect(
			_on_shooter_projectile_launched
		)


func _sync_loops() -> void:
	var simulation_active: bool = (
		enabled and _game_flow.is_world_simulation_active()
	)
	_set_loop_state(
		SOUND_SHIELD_CHARGE,
		simulation_active and _contact.is_contact_active()
	)
	_set_loop_state(
		SOUND_SHIELD_ALERT,
		simulation_active and _has_critical_shield_section()
	)
	_set_loop_state(
		SOUND_HEALER_HEAL,
		simulation_active and _healing_active
	)
	_set_loop_state(
		SOUND_PLATFORM_MOVE,
		simulation_active
		and absf(_platform.horizontal_velocity) >= movement_velocity_threshold
	)


func _set_loop_state(sound_id: StringName, should_play: bool) -> void:
	var player: AudioStreamPlayer = _loop_players.get(sound_id)
	if player == null:
		return
	var previous: bool = bool(_loop_states.get(sound_id, false))
	if previous == should_play:
		return
	_loop_states[sound_id] = should_play
	if should_play:
		player.volume_db = _get_sound_volume_db(sound_id, loop_volume_db)
		player.play()
		_record_trigger(sound_id)
	else:
		player.stop()


func _has_critical_shield_section() -> bool:
	for section_id: int in range(_shield.get_section_count()):
		if _shield.is_critical(section_id):
			return true
	return false


func _play_one_shot(sound_id: StringName, stream: AudioStream) -> void:
	if not enabled or stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.name = "OneShot%s" % String(sound_id).to_pascal_case()
	player.stream = stream
	player.bus = String(AppSettings.EFFECTS_BUS)
	player.volume_db = _get_sound_volume_db(sound_id, one_shot_volume_db)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
	_record_trigger(sound_id)


func _get_sound_volume_db(sound_id: StringName, base_db: float) -> float:
	var value: float = AppSettings.get_sound_volume(sound_id)
	if value <= 0.0001:
		return -80.0
	return base_db + linear_to_db(value)


func _apply_audio_mix() -> void:
	for sound_id: StringName in _loop_players:
		var player: AudioStreamPlayer = _loop_players[sound_id]
		player.bus = String(AppSettings.EFFECTS_BUS)
		player.volume_db = _get_sound_volume_db(sound_id, loop_volume_db)


func _record_trigger(sound_id: StringName) -> void:
	_trigger_counts[sound_id] = get_trigger_count(sound_id) + 1
	sound_triggered.emit(sound_id)


func _stop_all_one_shots() -> void:
	for child: Node in get_children():
		var player: AudioStreamPlayer = child as AudioStreamPlayer
		if player == null or _loop_players.values().has(player):
			continue
		player.stop()
		player.queue_free()


func _on_audio_settings_changed() -> void:
	_apply_audio_mix()


func _on_defender_spawned(_defender_id: int, defender: Defender) -> void:
	_connect_defender(defender)


func _on_defender_melee_attack_started(_target: HealthComponent) -> void:
	_play_one_shot(SOUND_DEFENDER_ATTACK, DEFENDER_ATTACK_STREAM)


func _on_shooter_projectile_launched(
	_target: HealthComponent,
	_start_position: Vector2,
	_target_position: Vector2
) -> void:
	_play_one_shot(SOUND_SHOOTER_ATTACK, SHOOTER_ATTACK_STREAM)


func _on_defender_died(_defender_id: int) -> void:
	_play_one_shot(SOUND_DEFENDER_DIE, DEFENDER_DIE_STREAM)


func _on_enemy_removed(_enemy_id: int, _reason: StringName) -> void:
	_play_one_shot(SOUND_MONSTER_DIE, MONSTER_DIE_STREAM)


func _on_replacement_completed(
	_defender_id: int,
	_defender: Defender
) -> void:
	_play_one_shot(SOUND_PORTAL, PORTAL_STREAM)


func _on_healing_started(_medic_id: int, _target_id: int) -> void:
	_healing_active = true
	_sync_loops()


func _on_healing_stopped(_medic_id: int, _target_id: int) -> void:
	_healing_active = false
	_sync_loops()


func _on_turret_shot_started(
	_buildable_id: int,
	_operator_id: int,
	_enemy_id: int
) -> void:
	_play_one_shot(SOUND_TURRET_ATTACK, TURRET_ATTACK_STREAM)


func _on_anchor_attached(_anchor_id: int) -> void:
	_play_one_shot(SOUND_WINCH_CONNECT, WINCH_CONNECT_STREAM)


func _on_anchor_removed(_anchor_id: int) -> void:
	_play_one_shot(SOUND_WINCH_DISCONNECT, WINCH_DISCONNECT_STREAM)


func _on_anchor_broken(_anchor_id: int) -> void:
	_play_one_shot(SOUND_WINCH_DISCONNECT, WINCH_DISCONNECT_STREAM)


func _on_completion_energy_shared(
	_source_section_id: int,
	_target_section_id: int,
	_amount: float
) -> void:
	_play_one_shot(SOUND_SHIELD_WAVE, SHIELD_WAVE_STREAM)


func _on_run_state_changed(_previous_state: int, _new_state: int) -> void:
	if _new_state == GameFlowController.RunState.START_DELAY:
		_healing_active = false
	_sync_loops()
