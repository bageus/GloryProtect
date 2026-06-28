class_name PlatformVisualControllerPolished
extends PlatformVisualController

const EMPTY_CAPTAIN_POST_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_captain_post_base.png"
)

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


func _draw_empty_driver_console() -> void:
	var source_rect: Rect2 = _empty_captain_post_source_rect
	var target_height: float = empty_console_size.y
	var scale: float = target_height / maxf(1.0, source_rect.size.y)
	var target_size := source_rect.size * scale
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
