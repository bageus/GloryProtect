class_name GameMusicController
extends Node

signal music_track_changed(track_id: StringName)

const GAMEPLAY_STREAM_1: AudioStream = preload(
	"res://audio/Melodic Drive Core.mp3"
)
const GAMEPLAY_STREAM_2: AudioStream = preload(
	"res://audio/Melodic Drive Core2.mp3"
)
const GAMEPLAY_STREAM_3: AudioStream = preload(
	"res://audio/Melodic Drive Core3.mp3"
)
const GAMEPLAY_STREAM_4: AudioStream = preload(
	"res://audio/Melodic core.mp3"
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
var _gameplay_track_index: int = 0
var _gameplay_player: AudioStreamPlayer
var _game_over_player: AudioStreamPlayer
var _gameplay_streams: Array[AudioStream] = [
	GAMEPLAY_STREAM_1,
	GAMEPLAY_STREAM_2,
	GAMEPLAY_STREAM_3,
	GAMEPLAY_STREAM_4,
]

@onready var _game_flow: GameFlowController = get_node(game_flow_path)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_gameplay_player = _create_music_player(
		"GameplayMusic",
		null,
		gameplay_volume_db
	)
	_gameplay_player.finished.connect(_on_gameplay_track_finished)
	_game_over_player = _create_music_player(
		"GameOverMusic",
		_make_loop_stream(GAME_OVER_STREAM),
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


func get_gameplay_track_count() -> int:
	return _gameplay_streams.size()


func get_current_gameplay_track_index() -> int:
	return _gameplay_track_index


func get_gameplay_track_paths_for_tests() -> PackedStringArray:
	var paths := PackedStringArray()
	for stream: AudioStream in _gameplay_streams:
		paths.append(stream.resource_path)
	return paths


func refresh_music_state_for_tests() -> void:
	_sync_to_run_state(_game_flow.state)


func advance_gameplay_track_for_tests() -> void:
	_on_gameplay_track_finished()


func _create_music_player(
	player_name: String,
	source: AudioStream,
	volume_db: float
) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = source
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


func _make_play_once_stream(source: AudioStream) -> AudioStream:
	var result: AudioStream = source.duplicate(true) as AudioStream
	if result is AudioStreamMP3:
		(result as AudioStreamMP3).loop = false
	elif result is AudioStreamOggVorbis:
		(result as AudioStreamOggVorbis).loop = false
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
			_play_gameplay_track(_gameplay_track_index)
		TRACK_GAME_OVER:
			_game_over_player.volume_db = game_over_volume_db
			_game_over_player.play()
	music_track_changed.emit(track_id)


func _play_gameplay_track(track_index: int) -> void:
	if _gameplay_streams.is_empty():
		return
	_gameplay_track_index = wrapi(track_index, 0, _gameplay_streams.size())
	_gameplay_player.stop()
	_gameplay_player.stream = _make_play_once_stream(
		_gameplay_streams[_gameplay_track_index]
	)
	_gameplay_player.volume_db = gameplay_volume_db
	_gameplay_player.play()


func _on_gameplay_track_finished() -> void:
	if _active_track != TRACK_GAMEPLAY:
		return
	_play_gameplay_track(_gameplay_track_index + 1)


func _on_run_state_changed(_previous_state: int, new_state: int) -> void:
	_sync_to_run_state(new_state)
