class_name GameMusicController
extends Node

signal music_track_changed(track_id: StringName)

const GAMEPLAY_STREAM: AudioStream = preload(
	"res://audio/Melodic Drive Core.mp3"
)
const GAME_OVER_STREAM: AudioStream = preload(
	"res://audio/game_over.ogg"
)

const TRACK_NONE: StringName = &"none"
const TRACK_GAMEPLAY: StringName = &"gameplay"
const TRACK_GAME_OVER: StringName = &"game_over"

@export_node_path("GameFlowController") var game_flow_path: NodePath

@export_group("Mix")
@export_range(-40.0, 6.0, 0.5) var gameplay_volume_db: float = -6.0
@export_range(-40.0, 6.0, 0.5) var game_over_volume_db: float = -6.0

var _active_track: StringName = TRACK_NONE
var _gameplay_player: AudioStreamPlayer
var _game_over_player: AudioStreamPlayer

@onready var _game_flow: GameFlowController = get_node(game_flow_path)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_gameplay_player = _create_music_player(
		"GameplayMusic",
		GAMEPLAY_STREAM,
		gameplay_volume_db
	)
	_game_over_player = _create_music_player(
		"GameOverMusic",
		GAME_OVER_STREAM,
		game_over_volume_db
	)
	if not _game_flow.run_state_changed.is_connected(_on_run_state_changed):
		_game_flow.run_state_changed.connect(_on_run_state_changed)
	_sync_to_run_state(_game_flow.state)


func get_current_track() -> StringName:
	return _active_track


func is_gameplay_music_active() -> bool:
	return _active_track == TRACK_GAMEPLAY


func is_game_over_music_active() -> bool:
	return _active_track == TRACK_GAME_OVER


func refresh_music_state_for_tests() -> void:
	_sync_to_run_state(_game_flow.state)


func _create_music_player(
	player_name: String,
	source: AudioStream,
	volume_db: float
) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = _make_loop_stream(source)
	player.bus = String(AppSettingsService.MUSIC_BUS)
	player.volume_db = volume_db
	add_child(player)
	return player


func _make_loop_stream(source: AudioStream) -> AudioStream:
	var result: AudioStream = source.duplicate(true) as AudioStream
	if result is AudioStreamMP3:
		(result as AudioStreamMP3).loop = true
	elif result is AudioStreamOggVorbis:
		(result as AudioStreamOggVorbis).loop = true
	return result


func _sync_to_run_state(run_state: int) -> void:
	match run_state:
		GameFlowController.RunState.BOOT:
			_set_active_track(TRACK_NONE)
		GameFlowController.RunState.GAME_OVER:
			_set_active_track(TRACK_GAME_OVER)
		_:
			_set_active_track(TRACK_GAMEPLAY)


func _set_active_track(track_id: StringName) -> void:
	if _active_track == track_id:
		return
	_gameplay_player.stop()
	_game_over_player.stop()
	_active_track = track_id
	match track_id:
		TRACK_GAMEPLAY:
			_gameplay_player.volume_db = gameplay_volume_db
			_gameplay_player.play()
		TRACK_GAME_OVER:
			_game_over_player.volume_db = game_over_volume_db
			_game_over_player.play()
	music_track_changed.emit(track_id)


func _on_run_state_changed(_previous_state: int, new_state: int) -> void:
	_sync_to_run_state(new_state)
