class_name PlatformVisualController
extends Node2D

signal spawn_sequence_finished(defender_id: int)

enum PortalState {
	IDLE,
	FLASH,
	GHOST,
	FINISH,
}

@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("SteeringInputProvider") var steering_input_path: NodePath
@export var balance: PlatformBalance
@export var crew_balance: CrewBalance

@export_group("Asset Visuals")
@export_range(0.0, 4.0, 0.25) var platform_tile_overlap: float = 1.0
@export_range(0.0, 1.0, 0.01) var alpha_crop_threshold: float = 0.08
@export var show_cell_guides: bool = false
@export var platform_core_size: Vector2 = Vector2(112.0, 112.0)
@export_range(0.0, 1.0, 0.01) var platform_core_protrusion_ratio: float = 0.33
@export var platform_core_offset: Vector2 = Vector2.ZERO
@export_range(1, 24, 1) var platform_core_frame_count: int = 6
@export_range(1.0, 30.0, 0.5) var platform_core_frame_rate: float = 8.0

@export_group("Driver Console")
@export var driver_console_surface_offset: Vector2 = Vector2(0.0, -2.0)
@export var driver_console_size: Vector2 = Vector2(52.0, 42.0)
@export var driver_lever_mount_normalized: Vector2 = Vector2(0.5, 0.58)
@export var driver_lever_mount_offset: Vector2 = Vector2.ZERO
@export_range(12.0, 60.0, 1.0) var driver_lever_length: float = 34.0
@export_range(0.0, 60.0, 1.0) var driver_lever_max_angle_degrees: float = 24.0
@export_range(1.0, 30.0, 0.5) var driver_lever_response_speed: float = 13.0

@export_group("Portal Visual")
@export var portal_surface_offset: Vector2 = Vector2(0.0, 2.0)
@export var portal_size: Vector2 = Vector2(54.0, 82.0)
@export_range(1.0, 10.0, 0.5) var portal_frame_width: float = 4.0
@export_range(0.01, 2.0, 0.01) var portal_flash_duration: float = 0.18
@export_range(0.01, 2.0, 0.01) var portal_ghost_duration: float = 0.26
@export_range(0.01, 2.0, 0.01) var portal_finish_duration: float = 0.26

@onready var _platform: PlatformController = get_node(platform_path)
@onready var _steering_input: SteeringInputProvider = get_node(steering_input_path)

var _game_flow: GameFlowController
var _surface_visual := PlatformSurfaceVisual.new()
var _driver_lever_angle: float = 0.0
var _portal_state: PortalState = PortalState.IDLE
var _portal_state_elapsed: float = 0.0
var _portal_active_defender_id: int = -1
var _portal_queue: Array[int] = []


func _ready() -> void:
	assert(balance != null, "PlatformVisualController requires PlatformBalance")
	assert(crew_balance != null, "PlatformVisualController requires CrewBalance")
	_surface_visual.configure(
		platform_core_frame_count,
		alpha_crop_threshold
	)
	var scene_root: Node = get_tree().current_scene
	if scene_root != null:
		_game_flow = scene_root.get_node_or_null(
			"GameFlowController"
		) as GameFlowController
	_steering_input.driver_availability_changed.connect(_on_visual_state_changed)
	queue_redraw()


func _process(delta: float) -> void:
	var simulation_active: bool = (
		_game_flow == null
		or _game_flow.is_world_simulation_active()
	)
	if simulation_active:
		_surface_visual.advance(delta)
		_update_driver_lever(delta)
		_update_portal(delta)
	queue_redraw()


func play_spawn(defender_id: int) -> void:
	if defender_id < 0:
		return
	if defender_id == _portal_active_defender_id or _portal_queue.has(defender_id):
		return
	_portal_queue.append(defender_id)
	if _portal_state == PortalState.IDLE:
		_start_next_portal_sequence()


func is_portal_busy() -> bool:
	return _portal_state != PortalState.IDLE or not _portal_queue.is_empty()


func _draw() -> void:
	var platform_width: float = _platform.get_platform_width()
	_surface_visual.draw_body(
		self,
		platform_width,
		balance.platform_height,
		balance.cell_count,
		balance.cell_width,
		platform_tile_overlap
	)
	if show_cell_guides:
		_draw_cells(platform_width)
	_draw_portal()
	_draw_driver_console()
	_surface_visual.draw_core(
		self,
		balance.platform_height,
		platform_core_size,
		platform_core_protrusion_ratio,
		platform_core_offset,
		platform_core_frame_rate,
		_steering_input.driver_available
	)


func _draw_cells(platform_width: float) -> void:
	for index: int in range(1, balance.cell_count):
		var x: float = -platform_width * 0.5 + float(index) * balance.cell_width
		draw_line(
			Vector2(x, -balance.platform_height * 0.5),
			Vector2(x, balance.platform_height * 0.5),
			Color(0.82, 0.9, 0.96, 0.18),
			1.0
		)


func _draw_portal() -> void:
	var platform_top: float = -balance.platform_height * 0.5
	var portal_bottom := Vector2(
		crew_balance.replacement_door_local_x + portal_surface_offset.x,
		platform_top + portal_surface_offset.y
	)
	var portal_center := portal_bottom - Vector2(0.0, portal_size.y * 0.5)
	var portal_rect := Rect2(portal_center - portal_size * 0.5, portal_size)
	var frame_tint := Color(0.28, 0.78, 1.0, 0.92)
	if _portal_state != PortalState.IDLE:
		frame_tint = Color(0.55, 0.94, 1.0, 1.0)

	draw_rect(portal_rect, Color(0.025, 0.055, 0.09, 0.88), true)
	draw_rect(portal_rect, frame_tint, false, portal_frame_width)
	draw_line(
		portal_rect.position + Vector2(portal_frame_width, portal_rect.size.y),
		portal_rect.end - Vector2(portal_frame_width, 0.0),
		Color(0.12, 0.35, 0.48, 0.95),
		portal_frame_width
	)
	_draw_portal_idle_energy(portal_center)

	if _portal_state == PortalState.IDLE:
		return
	if _portal_state == PortalState.FLASH:
		var progress: float = clampf(
			_portal_state_elapsed / maxf(portal_flash_duration, 0.01),
			0.0,
			1.0
		)
		_draw_portal_energy_pulse(portal_center, progress, sin(progress * PI))
		return

	var ghost_alpha: float = 0.38
	if _portal_state == PortalState.FINISH:
		ghost_alpha = lerpf(
			0.5,
			0.88,
			clampf(
				_portal_state_elapsed / maxf(portal_finish_duration, 0.01),
				0.0,
				1.0
			)
		)
	_draw_portal_defender_ghost(portal_center + Vector2(0.0, 6.0), ghost_alpha)

	if _portal_state == PortalState.FINISH:
		var finish_progress: float = clampf(
			_portal_state_elapsed / maxf(portal_finish_duration, 0.01),
			0.0,
			1.0
		)
		_draw_portal_energy_pulse(
			portal_center,
			finish_progress,
			sin(finish_progress * PI)
		)


func _draw_portal_idle_energy(portal_center: Vector2) -> void:
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
	var inner_size := Vector2(
		maxf(4.0, portal_size.x - portal_frame_width * 3.0),
		maxf(4.0, portal_size.y - portal_frame_width * 3.0)
	)
	var inner_rect := Rect2(portal_center - inner_size * 0.5, inner_size)
	draw_rect(
		inner_rect,
		Color(0.18, 0.76, 1.0, 0.06 + pulse * 0.08),
		true
	)


func _draw_portal_energy_pulse(
	portal_center: Vector2,
	progress: float,
	alpha: float
) -> void:
	var radius: float = lerpf(
		portal_size.x * 0.12,
		portal_size.x * 0.58,
		clampf(progress, 0.0, 1.0)
	)
	var safe_alpha: float = clampf(alpha, 0.0, 1.0)
	draw_circle(
		portal_center,
		radius,
		Color(0.24, 0.86, 1.0, safe_alpha * 0.16)
	)
	draw_arc(
		portal_center,
		radius,
		0.0,
		TAU,
		28,
		Color(0.72, 0.98, 1.0, safe_alpha),
		3.0
	)


func _draw_portal_defender_ghost(center: Vector2, alpha: float) -> void:
	var color: Color = _get_portal_defender_color(_portal_active_defender_id)
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


func _draw_driver_console() -> void:
	var platform_top: float = -balance.platform_height * 0.5
	var console_bottom := Vector2(
		driver_console_surface_offset.x,
		platform_top + driver_console_surface_offset.y
	)
	var console_rect := Rect2(
		console_bottom - Vector2(driver_console_size.x * 0.5, driver_console_size.y),
		driver_console_size
	)
	var console_tint := Color(0.48, 0.84, 1.0, 1.0)
	if not _steering_input.driver_available:
		console_tint = Color(0.55, 0.58, 0.62, 1.0)
	draw_rect(console_rect, Color(0.08, 0.13, 0.18, 0.96), true)
	draw_rect(console_rect, console_tint, false, 3.0)
	draw_circle(
		console_rect.position + Vector2(console_rect.size.x * 0.25, 12.0),
		4.0,
		console_tint
	)
	draw_circle(
		console_rect.position + Vector2(console_rect.size.x * 0.75, 12.0),
		4.0,
		console_tint.darkened(0.25)
	)

	var lever_mount := Vector2(
		console_rect.position.x
			+ console_rect.size.x * driver_lever_mount_normalized.x,
		console_rect.position.y
			+ console_rect.size.y * driver_lever_mount_normalized.y
	) + driver_lever_mount_offset
	draw_set_transform(lever_mount, _driver_lever_angle, Vector2.ONE)
	draw_line(Vector2.ZERO, Vector2(0.0, -driver_lever_length), console_tint, 6.0, true)
	draw_circle(Vector2(0.0, -driver_lever_length), 8.0, console_tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _update_driver_lever(delta: float) -> void:
	var steering_axis: float = _steering_input.get_steering_axis()
	var maximum_angle: float = deg_to_rad(driver_lever_max_angle_degrees)
	var target_angle: float = steering_axis * maximum_angle
	_driver_lever_angle = lerp_angle(
		_driver_lever_angle,
		target_angle,
		clampf(delta * driver_lever_response_speed, 0.0, 1.0)
	)
	if absf(_driver_lever_angle - target_angle) <= 0.0005:
		_driver_lever_angle = target_angle


func _update_portal(delta: float) -> void:
	if _portal_state == PortalState.IDLE:
		return
	_portal_state_elapsed += maxf(0.0, delta)
	match _portal_state:
		PortalState.FLASH:
			if _portal_state_elapsed >= portal_flash_duration:
				_set_portal_state(PortalState.GHOST)
		PortalState.GHOST:
			if _portal_state_elapsed >= portal_ghost_duration:
				_set_portal_state(PortalState.FINISH)
		PortalState.FINISH:
			if _portal_state_elapsed >= portal_finish_duration:
				_finish_portal_sequence()


func _start_next_portal_sequence() -> void:
	if _portal_queue.is_empty():
		_portal_active_defender_id = -1
		_set_portal_state(PortalState.IDLE)
		return
	_portal_active_defender_id = _portal_queue.pop_front()
	_set_portal_state(PortalState.FLASH)


func _finish_portal_sequence() -> void:
	var completed_id: int = _portal_active_defender_id
	_portal_active_defender_id = -1
	_set_portal_state(PortalState.IDLE)
	spawn_sequence_finished.emit(completed_id)
	call_deferred("_start_next_portal_sequence")


func _set_portal_state(new_state: PortalState) -> void:
	_portal_state = new_state
	_portal_state_elapsed = 0.0
	queue_redraw()


func _get_portal_defender_color(defender_id: int) -> Color:
	var colors: Array[Color] = [
		Color(0.35, 0.84, 1.0),
		Color(1.0, 0.68, 0.32),
		Color(0.58, 0.92, 0.48),
		Color(0.86, 0.5, 1.0),
	]
	return colors[maxi(0, defender_id) % colors.size()]


func _on_visual_state_changed(_is_available: bool) -> void:
	queue_redraw()
