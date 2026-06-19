class_name PlatformVisualController
extends Node2D

@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("SteeringInputProvider") var steering_input_path: NodePath
@export var balance: PlatformBalance
@export var crew_balance: CrewBalance

@onready var _platform: PlatformController = get_node(platform_path)
@onready var _steering_input: SteeringInputProvider = get_node(steering_input_path)


func _ready() -> void:
	assert(balance != null, "PlatformVisualController requires PlatformBalance")
	assert(crew_balance != null, "PlatformVisualController requires CrewBalance")
	_steering_input.driver_availability_changed.connect(_on_visual_state_changed)
	queue_redraw()


func _draw() -> void:
	var platform_width: float = _platform.get_platform_width()
	var platform_rect := Rect2(
		Vector2(-platform_width * 0.5, -balance.platform_height * 0.5),
		Vector2(platform_width, balance.platform_height)
	)

	draw_rect(platform_rect, Color(0.16, 0.22, 0.31), true)
	draw_rect(platform_rect, Color(0.55, 0.69, 0.82), false, 3.0)
	_draw_cells(platform_width)
	_draw_replacement_door()
	_draw_driver_post()
	_draw_anchor_posts(platform_width)
	_draw_platform_orb()


func _draw_cells(platform_width: float) -> void:
	for index: int in range(1, balance.cell_count):
		var x: float = (
			-platform_width * 0.5 + float(index) * balance.cell_width
		)
		draw_line(
			Vector2(x, -balance.platform_height * 0.5),
			Vector2(x, balance.platform_height * 0.5),
			Color(0.28, 0.36, 0.46),
			1.0
		)


func _draw_replacement_door() -> void:
	var door_width: float = balance.cell_width * 1.2
	var door_height: float = 34.0
	var door_rect := Rect2(
		Vector2(
			crew_balance.replacement_door_local_x - door_width * 0.5,
			-balance.platform_height * 0.5 - door_height
		),
		Vector2(door_width, door_height)
	)
	draw_rect(door_rect, Color(0.11, 0.15, 0.22), true)
	draw_rect(door_rect, Color(0.48, 0.61, 0.72), false, 2.0)
	draw_circle(
		door_rect.position + Vector2(door_width - 8.0, door_height * 0.5),
		2.5,
		Color(0.88, 0.72, 0.3)
	)


func _draw_driver_post() -> void:
	var post_rect := Rect2(
		Vector2(
			-balance.driver_post_width * 0.5,
			-balance.driver_post_height
		),
		Vector2(balance.driver_post_width, balance.driver_post_height)
	)
	draw_rect(post_rect, Color(0.26, 0.56, 0.75), true)
	draw_rect(post_rect, Color(0.75, 0.91, 1.0), false, 2.0)


func _draw_anchor_posts(platform_width: float) -> void:
	var offset: float = (
		platform_width * 0.5
		- balance.cell_width * balance.anchor_post_cell_inset
	)
	for side: float in [-1.0, 1.0]:
		var post_rect := Rect2(
			Vector2(
				side * offset - balance.anchor_post_width * 0.5,
				-balance.anchor_post_height
			),
			Vector2(balance.anchor_post_width, balance.anchor_post_height)
		)
		draw_rect(post_rect, Color(0.55, 0.42, 0.22), true)
		draw_rect(post_rect, Color(0.92, 0.72, 0.35), false, 2.0)


func _draw_platform_orb() -> void:
	var orb_color: Color = Color(0.35, 0.4, 0.45)
	if _steering_input.driver_available:
		orb_color = Color(0.35, 0.9, 1.0)
	draw_circle(Vector2.ZERO, 17.0, orb_color)
	draw_arc(
		Vector2.ZERO,
		25.0,
		0.0,
		TAU,
		48,
		Color(0.65, 0.96, 1.0),
		2.0
	)


func _on_visual_state_changed(_is_available: bool) -> void:
	queue_redraw()
