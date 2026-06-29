class_name PlatformVisualControllerPolished
extends PlatformVisualController

const EMPTY_CAPTAIN_POST_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_captain_post_base.png"
)

@export_group("Occupied Driver Console")
@export_range(1.0, 2.0, 0.05) var occupied_console_max_width_cells: float = 2.0
@export_range(0.0, 12.0, 1.0) var occupied_console_width_margin: float = 4.0

var _empty_captain_post_source_rect: Rect2


func _ready() -> void:
	_empty_captain_post_source_rect = TextureRegionLayout.get_alpha_bounds(
		EMPTY_CAPTAIN_POST_TEXTURE,
		alpha_crop_threshold
	)
	super._ready()


func has_empty_console_asset() -> bool:
	return (
		EMPTY_CAPTAIN_POST_TEXTURE != null
		and _empty_captain_post_source_rect.size.x > 0.0
		and _empty_captain_post_source_rect.size.y > 0.0
	)


func get_occupied_console_max_width() -> float:
	return maxf(
		1.0,
		balance.cell_width * occupied_console_max_width_cells
		- occupied_console_width_margin
	)


func get_occupied_console_size_for_axis(steering_axis: float) -> Vector2:
	var source_rect: Rect2 = _captain_center_source_rect
	if steering_axis < -0.01:
		source_rect = _captain_left_source_rect
	elif steering_axis > 0.01:
		source_rect = _captain_right_source_rect
	return _fit_occupied_console_size(source_rect)


func _draw_driver_console() -> void:
	if not _steering_input.driver_available:
		_draw_empty_driver_console()
		return
	var texture: Texture2D = CAPTAIN_CENTER_TEXTURE
	var source_rect: Rect2 = _captain_center_source_rect
	var steering_axis: float = _steering_input.get_steering_axis()
	if steering_axis < -0.01:
		texture = CAPTAIN_LEFT_TEXTURE
		source_rect = _captain_left_source_rect
	elif steering_axis > 0.01:
		texture = CAPTAIN_RIGHT_TEXTURE
		source_rect = _captain_right_source_rect
	var post_size: Vector2 = _fit_occupied_console_size(source_rect)
	var post_bottom: Vector2 = _get_driver_console_bottom()
	var post_rect := Rect2(
		post_bottom - Vector2(post_size.x * 0.5, post_size.y),
		post_size
	)
	draw_texture_rect_region(texture, post_rect, source_rect)


func _fit_occupied_console_size(source_rect: Rect2) -> Vector2:
	var target_size: Vector2 = source_rect.size * object_asset_scale
	var maximum_width: float = get_occupied_console_max_width()
	if target_size.x > maximum_width:
		target_size *= maximum_width / target_size.x
	return target_size


func _draw_empty_driver_console() -> void:
	var source_rect: Rect2 = _empty_captain_post_source_rect
	var target_height: float = empty_console_size.y
	var height_scale: float = target_height / maxf(1.0, source_rect.size.y)
	var target_size := source_rect.size * height_scale
	if target_size.x > empty_console_size.x:
		target_size *= empty_console_size.x / target_size.x
	var bottom: Vector2 = _get_driver_console_bottom()
	var rect := Rect2(
		bottom - Vector2(target_size.x * 0.5, target_size.y),
		target_size
	)
	draw_texture_rect_region(
		EMPTY_CAPTAIN_POST_TEXTURE,
		rect,
		source_rect,
		Color(0.72, 0.76, 0.8, 1.0)
	)
