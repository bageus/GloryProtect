class_name PlatformAnchorWinchVisual
extends Node2D

const WINCH_BASE_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_winch_01.png"
)
const STRONG_WINCH_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_winch_02.png"
)
const SPECIALIZATION_2_WINCH_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_winch_03.png"
)
const TRAP_WINCH_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_winch_04.png"
)

@export_range(0.0, 1.0, 0.01) var alpha_crop_threshold: float = 0.08
@export_range(1, 128, 1) var minimum_z_index: int = 14
@export var snap_visuals_to_canvas_pixels: bool = true
@export var winch_size: Vector2 = Vector2(58.0, 54.0)
@export var winch_surface_offset: Vector2 = Vector2(0.0, 2.0)

var _platform: PlatformController
var _anchors: AnchorSystem
var _combat_anchors: CombatAnchorSystem
var _source_rects: Dictionary[Texture2D, Rect2] = {}


func configure(
	platform: PlatformController,
	anchors: AnchorSystem,
	combat_anchors: CombatAnchorSystem = null
) -> void:
	_platform = platform
	_anchors = anchors
	_combat_anchors = combat_anchors
	_connect_combat_signals()
	queue_redraw()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_as_relative = false
	z_index = maxi(z_index, minimum_z_index)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for texture: Texture2D in _get_all_textures():
		_source_rects[texture] = TextureRegionLayout.get_alpha_bounds(
			texture,
			alpha_crop_threshold
		)
	_apply_canvas_pixel_snap()
	_connect_combat_signals()
	queue_redraw()


func _process(_delta: float) -> void:
	_apply_canvas_pixel_snap()
	queue_redraw()


func _draw() -> void:
	if _platform == null:
		return
	for anchor_id: int in range(4):
		_draw_winch(anchor_id)


func get_visible_winch_count_for_tests() -> int:
	if _platform == null:
		return 0
	return 4


func get_winch_asset_id_for_tests(anchor_id: int = 0) -> StringName:
	return _get_winch_asset_id(anchor_id)


func get_winch_center_for_tests(anchor_id: int) -> Vector2:
	return _get_winch_center(anchor_id)


func is_winch_drawable_for_tests(anchor_id: int) -> bool:
	var texture: Texture2D = _get_winch_texture(anchor_id)
	return _is_rect_drawable(_source_rects.get(texture, Rect2()))


func _draw_winch(anchor_id: int) -> void:
	var texture: Texture2D = _get_winch_texture(anchor_id)
	var center: Vector2 = _get_winch_center(anchor_id)
	var mirrored: bool = anchor_id == 1 or anchor_id == 3
	var tint: Color = Color.WHITE if _is_operator_available(anchor_id) else Color(
		0.52,
		0.55,
		0.58,
		1.0
	)
	_draw_texture_centered(texture, center, winch_size, mirrored, tint)


func _draw_texture_centered(
	texture: Texture2D,
	center: Vector2,
	target_size: Vector2,
	mirrored: bool,
	tint: Color
) -> void:
	var source_rect: Rect2 = _source_rects.get(texture, Rect2())
	if not _is_rect_drawable(source_rect):
		return
	var draw_size: Vector2 = TextureRegionLayout.fit_inside(
		source_rect.size,
		target_size
	)
	var rect := Rect2(-draw_size * 0.5, draw_size)
	var scale := Vector2(-1.0, 1.0) if mirrored else Vector2.ONE
	draw_set_transform(center, 0.0, scale)
	draw_texture_rect_region(texture, rect, source_rect, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _get_winch_center(anchor_id: int) -> Vector2:
	var bottom := Vector2(
		_get_anchor_local_x(anchor_id) + winch_surface_offset.x,
		_get_platform_surface_y() + winch_surface_offset.y
	)
	return bottom - Vector2(0.0, winch_size.y * 0.5)


func _get_anchor_local_x(anchor_id: int) -> float:
	if _platform == null:
		return 0.0
	match anchor_id:
		0:
			return _platform.get_cell_local_x(0)
		1:
			return _platform.get_cell_local_x(1)
		2:
			return _platform.get_cell_local_x(_platform.get_cell_count() - 2)
		3:
			return _platform.get_cell_local_x(_platform.get_cell_count() - 1)
		_:
			return 0.0


func _get_platform_surface_y() -> float:
	if _platform == null or _platform.balance == null:
		return -29.0
	return -_platform.get_platform_height() * 0.5


func _get_winch_texture(anchor_id: int) -> Texture2D:
	match _get_winch_asset_id(anchor_id):
		&"strong":
			return STRONG_WINCH_TEXTURE
		&"specialization_2":
			return SPECIALIZATION_2_WINCH_TEXTURE
		&"trap":
			return TRAP_WINCH_TEXTURE
		_:
			return WINCH_BASE_TEXTURE


func _get_winch_asset_id(_anchor_id: int) -> StringName:
	if _combat_anchors == null:
		return &"base"
	match _combat_anchors.upgrades.specialization_id:
		CombatAnchorUpgradeRuntime.STRONG:
			return &"strong"
		CombatAnchorUpgradeRuntime.ELECTRIC:
			return &"specialization_2"
		CombatAnchorUpgradeRuntime.TRAP:
			return &"trap"
		_:
			return &"base"


func _is_operator_available(anchor_id: int) -> bool:
	if _anchors == null:
		return true
	var side := AnchorRuntime.Side.LEFT if anchor_id < 2 else AnchorRuntime.Side.RIGHT
	return _anchors.is_operator_assigned(side)


func _connect_combat_signals() -> void:
	if _combat_anchors == null:
		return
	if not _combat_anchors.upgrades_changed.is_connected(_on_visual_state_changed):
		_combat_anchors.upgrades_changed.connect(_on_visual_state_changed)


func _apply_canvas_pixel_snap() -> void:
	if not snap_visuals_to_canvas_pixels:
		if position != Vector2.ZERO:
			position = Vector2.ZERO
		return
	var parent_canvas := get_parent() as CanvasItem
	if parent_canvas == null:
		return
	var canvas_origin: Vector2 = parent_canvas.get_global_transform_with_canvas().origin
	var snapped_position: Vector2 = canvas_origin.round() - canvas_origin
	if position != snapped_position:
		position = snapped_position


func _get_all_textures() -> Array[Texture2D]:
	return [
		WINCH_BASE_TEXTURE,
		STRONG_WINCH_TEXTURE,
		SPECIALIZATION_2_WINCH_TEXTURE,
		TRAP_WINCH_TEXTURE,
	]


func _is_rect_drawable(rect: Rect2) -> bool:
	return rect.size.x > 0.0 and rect.size.y > 0.0


func _on_visual_state_changed() -> void:
	queue_redraw()
