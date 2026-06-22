class_name PlatformVisualController
extends Node2D

const PLATFORM_TILE_TEXTURE: Texture2D = preload(
	"res://visual/tiles/tile_platform.png"
)
const PLATFORM_CORE_TEXTURE: Texture2D = preload(
	"res://visual/tiles/tile_core_platform_energy.png"
)

@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("SteeringInputProvider") var steering_input_path: NodePath
@export var balance: PlatformBalance
@export var crew_balance: CrewBalance

@export_group("Asset Visuals")
@export_range(0.0, 4.0, 0.25) var platform_tile_overlap: float = 1.0
@export var show_cell_guides: bool = false
@export var platform_core_size: Vector2 = Vector2(112.0, 112.0)
@export_range(0.0, 1.0, 0.01) var platform_core_protrusion_ratio: float = 0.33
@export var platform_core_offset: Vector2 = Vector2.ZERO

@onready var _platform: PlatformController = get_node(platform_path)
@onready var _steering_input: SteeringInputProvider = get_node(steering_input_path)

var _platform_tile_source_rect: Rect2


func _ready() -> void:
	assert(balance != null, "PlatformVisualController requires PlatformBalance")
	assert(crew_balance != null, "PlatformVisualController requires CrewBalance")
	_platform_tile_source_rect = _get_used_texture_rect(PLATFORM_TILE_TEXTURE)
	_steering_input.driver_availability_changed.connect(_on_visual_state_changed)
	queue_redraw()


func _draw() -> void:
	var platform_width: float = _platform.get_platform_width()
	var platform_rect := Rect2(
		Vector2(-platform_width * 0.5, -balance.platform_height * 0.5),
		Vector2(platform_width, balance.platform_height)
	)

	# The solid body remains behind transparent holes inside the tile artwork.
	draw_rect(platform_rect, Color(0.12, 0.17, 0.24), true)
	_draw_platform_tiles(platform_width)
	draw_rect(platform_rect, Color(0.55, 0.69, 0.82, 0.45), false, 2.0)
	if show_cell_guides:
		_draw_cells(platform_width)
	_draw_driver_post()
	_draw_anchor_posts(platform_width)
	_draw_platform_orb()


func _draw_platform_tiles(platform_width: float) -> void:
	var first_x: float = -platform_width * 0.5
	var half_overlap: float = platform_tile_overlap * 0.5
	for index: int in range(balance.cell_count):
		var tile_rect := Rect2(
			Vector2(
				first_x + float(index) * balance.cell_width - half_overlap,
				-balance.platform_height * 0.5
			),
			Vector2(
				balance.cell_width + platform_tile_overlap,
				balance.platform_height
			)
		)
		draw_texture_rect_region(
			PLATFORM_TILE_TEXTURE,
			tile_rect,
			_platform_tile_source_rect
		)


func _draw_cells(platform_width: float) -> void:
	for index: int in range(1, balance.cell_count):
		var x: float = (
			-platform_width * 0.5 + float(index) * balance.cell_width
		)
		draw_line(
			Vector2(x, -balance.platform_height * 0.5),
			Vector2(x, balance.platform_height * 0.5),
			Color(0.82, 0.9, 0.96, 0.18),
			1.0
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
	var core_tint := Color.WHITE
	if not _steering_input.driver_available:
		core_tint = Color(0.42, 0.46, 0.5, 1.0)

	# A protrusion ratio of 0.33 places one third of the core below the platform.
	var platform_bottom: float = balance.platform_height * 0.5
	var core_center_y: float = (
		platform_bottom
		+ (platform_core_protrusion_ratio - 0.5) * platform_core_size.y
	)
	var core_center := Vector2(0.0, core_center_y) + platform_core_offset
	var core_rect := Rect2(
		core_center - platform_core_size * 0.5,
		platform_core_size
	)
	draw_texture_rect(
		PLATFORM_CORE_TEXTURE,
		core_rect,
		false,
		core_tint
	)


func _get_used_texture_rect(texture: Texture2D) -> Rect2:
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return Rect2(Vector2.ZERO, texture.get_size())
	var used_rect: Rect2i = image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return Rect2(Vector2.ZERO, texture.get_size())
	return Rect2(
		Vector2(used_rect.position),
		Vector2(used_rect.size)
	)


func _on_visual_state_changed(_is_available: bool) -> void:
	queue_redraw()
