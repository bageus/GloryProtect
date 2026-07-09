class_name PlatformWindCompensatorVisual
extends Node2D

const BASE_TEXTURE: Texture2D = preload(
	"res://visual/objects/platform/core/asset_air_02.png"
)
const ACTIVE_TEXTURE: Texture2D = preload(
	"res://visual/objects/platform/core/asset_air_01.png"
)

@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("WindSystem") var wind_system_path: NodePath
@export_node_path("AnchorlessControlSystem") var anchorless_control_system_path: NodePath = NodePath(
	"../../AnchorlessControlSystem"
)
@export_range(0.0, 1.0, 0.01) var alpha_crop_threshold: float = 0.08
@export var compensator_size: Vector2 = Vector2(48.0, 36.0)
@export_range(0.0, 24.0, 0.25) var anchor_post_gap: float = 4.0
@export_range(0.0, 24.0, 0.25) var platform_attach_overlap: float = 4.0
@export_range(-24.0, 24.0, 0.25) var vertical_offset: float = 0.0

var _base_source_rect: Rect2
var _active_source_rect: Rect2

@onready var _platform: PlatformController = get_node(platform_path)
@onready var _wind: WindSystem = get_node(wind_system_path)
@onready var _anchorless: AnchorlessControlSystem = get_node_or_null(
	anchorless_control_system_path
) as AnchorlessControlSystem


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base_source_rect = TextureRegionLayout.get_alpha_bounds(
		BASE_TEXTURE,
		alpha_crop_threshold
	)
	_active_source_rect = TextureRegionLayout.get_alpha_bounds(
		ACTIVE_TEXTURE,
		alpha_crop_threshold
	)
	if not _wind.wind_state_changed.is_connected(_on_wind_state_changed):
		_wind.wind_state_changed.connect(_on_wind_state_changed)
	_connect_anchorless_control_system()
	_refresh_visibility()


func _process(_delta: float) -> void:
	_connect_anchorless_control_system()
	_refresh_visibility()


func _draw() -> void:
	if not is_compensator_visible_for_tests():
		return
	for side: int in [-1, 1]:
		_draw_compensator(side)


func is_compensator_visible_for_tests() -> bool:
	return _anchorless != null and _anchorless.upgrades.wind_reduction_ratio > 0.0


func get_active_side_for_tests() -> int:
	if not is_compensator_visible_for_tests():
		return 0
	if _wind == null or is_zero_approx(_wind.get_current_force()):
		return 0
	return 1 if _wind.get_current_force() > 0.0 else -1


func get_compensator_centers_for_tests() -> Array[Vector2]:
	return [_get_compensator_center(-1), _get_compensator_center(1)]


func get_compensator_draw_size_for_tests() -> Vector2:
	return _get_draw_size(_base_source_rect)


func get_platform_bottom_y_for_tests() -> float:
	return _get_platform_bottom_y()


func get_anchor_post_inner_edge_x_for_tests(side: int) -> float:
	return _get_anchor_post_inner_edge_x(side)


func is_side_mirrored_for_tests(side: int) -> bool:
	return side < 0


func _draw_compensator(side: int) -> void:
	var active_side: int = get_active_side_for_tests()
	var texture: Texture2D = BASE_TEXTURE
	var source_rect: Rect2 = _base_source_rect
	if active_side == side:
		texture = ACTIVE_TEXTURE
		source_rect = _active_source_rect
	_draw_texture(texture, source_rect, _get_compensator_center(side), side < 0)


func _draw_texture(
	texture: Texture2D,
	source_rect: Rect2,
	center: Vector2,
	mirrored: bool
) -> void:
	var draw_size: Vector2 = _get_draw_size(source_rect)
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return
	var rect := Rect2(-draw_size * 0.5, draw_size)
	var scale := Vector2(-1.0, 1.0) if mirrored else Vector2.ONE
	draw_set_transform(center, 0.0, scale)
	draw_texture_rect_region(texture, rect, source_rect)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _get_compensator_center(side: int) -> Vector2:
	var normalized_side: int = -1 if side < 0 else 1
	var draw_size: Vector2 = _get_draw_size(_base_source_rect)
	var inner_edge_x: float = _get_anchor_post_inner_edge_x(normalized_side)
	return Vector2(
		inner_edge_x - float(normalized_side) * (anchor_post_gap + draw_size.x * 0.5),
		_get_platform_bottom_y() - platform_attach_overlap + draw_size.y * 0.5 + vertical_offset
	)


func _get_anchor_post_inner_edge_x(side: int) -> float:
	var normalized_side: int = -1 if side < 0 else 1
	if _platform == null or _platform.balance == null:
		return 0.0
	if normalized_side < 0:
		var left_inner_post: int = mini(1, _platform.get_cell_count() - 1)
		return (
			_platform.get_cell_local_x(left_inner_post)
			+ _platform.balance.anchor_post_width * 0.5
		)
	var right_inner_post: int = maxi(0, _platform.get_cell_count() - 2)
	return (
		_platform.get_cell_local_x(right_inner_post)
		- _platform.balance.anchor_post_width * 0.5
	)


func _get_platform_bottom_y() -> float:
	if _platform == null:
		return 0.0
	return _platform.get_platform_height() * 0.5


func _get_draw_size(source_rect: Rect2) -> Vector2:
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return Vector2.ZERO
	return TextureRegionLayout.fit_inside(source_rect.size, compensator_size)


func _connect_anchorless_control_system() -> void:
	if _anchorless == null:
		_anchorless = get_node_or_null(
			anchorless_control_system_path
		) as AnchorlessControlSystem
	if _anchorless == null:
		return
	if not _anchorless.upgrades_changed.is_connected(_on_anchorless_upgrades_changed):
		_anchorless.upgrades_changed.connect(_on_anchorless_upgrades_changed)


func _refresh_visibility() -> void:
	var should_show: bool = is_compensator_visible_for_tests()
	if visible != should_show:
		visible = should_show
	queue_redraw()


func _on_anchorless_upgrades_changed() -> void:
	_refresh_visibility()


func _on_wind_state_changed(
	_direction: int,
	_strength_level: int,
	_base_force: float
) -> void:
	queue_redraw()
