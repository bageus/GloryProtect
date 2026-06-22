class_name CrewPortalVisualController
extends Node2D

signal spawn_sequence_finished(defender_id: int)

const PORTAL_TEXTURE: Texture2D = preload(
	"res://visual/objects/portal/asset_object_portal.png"
)
const SPAWN_FLASH_TEXTURE: Texture2D = preload(
	"res://visual/objects/portal/overlay_object_portal_spawn1.png"
)
const SPAWN_FINISH_TEXTURE: Texture2D = preload(
	"res://visual/objects/portal/overlay_object_portal_spawn2.png"
)

const ALPHA_CROP_THRESHOLD: float = 0.08

enum State {
	IDLE,
	FLASH,
	GHOST,
	FINISH,
}

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export var crew_balance: CrewBalance

@export_group("Portal Visual")
@export var portal_size: Vector2 = Vector2(136.0, 136.0)
@export var portal_local_y: float = -82.0
@export var portal_offset: Vector2 = Vector2.ZERO
@export var overlay_size: Vector2 = Vector2(104.0, 104.0)
@export var overlay_offset: Vector2 = Vector2(0.0, 2.0)

@export_group("Spawn Timing")
@export_range(0.01, 2.0, 0.01) var flash_duration: float = 0.18
@export_range(0.01, 2.0, 0.01) var ghost_duration: float = 0.26
@export_range(0.01, 2.0, 0.01) var finish_duration: float = 0.26

@onready var _game_flow: GameFlowController = get_node(game_flow_path)

var _state: State = State.IDLE
var _state_elapsed: float = 0.0
var _active_defender_id: int = -1
var _queue: Array[int] = []
var _portal_source_rect: Rect2
var _flash_source_rect: Rect2
var _finish_source_rect: Rect2


func _ready() -> void:
	assert(crew_balance != null, "CrewPortalVisualController requires CrewBalance")
	_portal_source_rect = _get_alpha_bounds(PORTAL_TEXTURE)
	_flash_source_rect = _get_alpha_bounds(SPAWN_FLASH_TEXTURE)
	_finish_source_rect = _get_alpha_bounds(SPAWN_FINISH_TEXTURE)
	queue_redraw()


func _process(delta: float) -> void:
	if _state == State.IDLE:
		return
	if not _game_flow.is_world_simulation_active():
		return

	_state_elapsed += maxf(0.0, delta)
	match _state:
		State.FLASH:
			if _state_elapsed >= flash_duration:
				_set_state(State.GHOST)
		State.GHOST:
			if _state_elapsed >= ghost_duration:
				_set_state(State.FINISH)
		State.FINISH:
			if _state_elapsed >= finish_duration:
				_finish_active_sequence()
	queue_redraw()


func play_spawn(defender_id: int) -> void:
	if defender_id < 0:
		return
	if defender_id == _active_defender_id or _queue.has(defender_id):
		return
	_queue.append(defender_id)
	if _state == State.IDLE:
		_start_next_sequence()


func is_busy() -> bool:
	return _state != State.IDLE or not _queue.is_empty()


func _draw() -> void:
	var center := _get_portal_center()
	var portal_rect := Rect2(center - portal_size * 0.5, portal_size)
	draw_texture_rect_region(
		PORTAL_TEXTURE,
		portal_rect,
		_portal_source_rect
	)

	if _state == State.IDLE:
		return

	if _state == State.FLASH:
		var flash_progress: float = clampf(
			_state_elapsed / maxf(flash_duration, 0.01),
			0.0,
			1.0
		)
		_draw_overlay(
			SPAWN_FLASH_TEXTURE,
			_flash_source_rect,
			center,
			Color(1.0, 1.0, 1.0, sin(flash_progress * PI))
		)
		return

	var ghost_alpha: float = 0.38
	if _state == State.FINISH:
		ghost_alpha = lerpf(
			0.5,
			0.88,
			clampf(
				_state_elapsed / maxf(finish_duration, 0.01),
				0.0,
				1.0
			)
		)
	_draw_defender_ghost(center + Vector2(0.0, 6.0), ghost_alpha)

	if _state == State.FINISH:
		var finish_progress: float = clampf(
			_state_elapsed / maxf(finish_duration, 0.01),
			0.0,
			1.0
		)
		_draw_overlay(
			SPAWN_FINISH_TEXTURE,
			_finish_source_rect,
			center,
			Color(1.0, 1.0, 1.0, sin(finish_progress * PI))
		)


func _draw_overlay(
	texture: Texture2D,
	source_rect: Rect2,
	center: Vector2,
	modulate: Color
) -> void:
	var rect := Rect2(
		center + overlay_offset - overlay_size * 0.5,
		overlay_size
	)
	draw_texture_rect_region(texture, rect, source_rect, modulate)


func _draw_defender_ghost(center: Vector2, alpha: float) -> void:
	var color: Color = _get_defender_color(_active_defender_id)
	color.a = alpha
	var outline := Color(0.75, 0.96, 1.0, alpha * 0.9)

	draw_circle(center + Vector2(0.0, -24.0), 10.0, color)
	draw_rect(
		Rect2(center + Vector2(-10.0, -14.0), Vector2(20.0, 30.0)),
		color,
		true
	)
	draw_line(
		center + Vector2(-7.0, 16.0),
		center + Vector2(-10.0, 31.0),
		color,
		6.0,
		true
	)
	draw_line(
		center + Vector2(7.0, 16.0),
		center + Vector2(10.0, 31.0),
		color,
		6.0,
		true
	)
	draw_arc(center + Vector2(0.0, -24.0), 11.5, 0.0, TAU, 20, outline, 2.0)


func _get_portal_center() -> Vector2:
	return Vector2(
		crew_balance.replacement_door_local_x,
		portal_local_y
	) + portal_offset


func _start_next_sequence() -> void:
	if _queue.is_empty():
		_active_defender_id = -1
		_set_state(State.IDLE)
		return
	_active_defender_id = _queue.pop_front()
	_set_state(State.FLASH)


func _finish_active_sequence() -> void:
	var completed_id: int = _active_defender_id
	_active_defender_id = -1
	_set_state(State.IDLE)
	spawn_sequence_finished.emit(completed_id)
	call_deferred("_start_next_sequence")


func _set_state(new_state: State) -> void:
	_state = new_state
	_state_elapsed = 0.0
	queue_redraw()


func _get_defender_color(defender_id: int) -> Color:
	var colors: Array[Color] = [
		Color(0.35, 0.84, 1.0),
		Color(1.0, 0.68, 0.32),
		Color(0.58, 0.92, 0.48),
		Color(0.86, 0.5, 1.0),
	]
	return colors[maxi(0, defender_id) % colors.size()]


func _get_alpha_bounds(texture: Texture2D) -> Rect2:
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return Rect2(Vector2.ZERO, texture.get_size())

	var width: int = image.get_width()
	var height: int = image.get_height()
	var min_x: int = width
	var min_y: int = height
	var max_x: int = -1
	var max_y: int = -1

	for y: int in range(height):
		for x: int in range(width):
			if image.get_pixel(x, y).a <= ALPHA_CROP_THRESHOLD:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)

	if max_x < min_x or max_y < min_y:
		return Rect2(Vector2.ZERO, texture.get_size())

	return Rect2(
		Vector2(float(min_x), float(min_y)),
		Vector2(
			float(max_x - min_x + 1),
			float(max_y - min_y + 1)
		)
	)
