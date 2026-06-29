class_name ParallaxSceneBackground
extends CanvasLayer

@export_node_path("Node2D") var platform_path: NodePath
@export_range(0.0, 1.0, 0.001) var far_motion_scale: float = 0.035
@export_range(0.0, 1.0, 0.001) var near_motion_scale: float = 0.075
@export_range(1.0, 2.0, 0.01) var overscan_ratio: float = 1.25

@onready var _far_layer: Sprite2D = $FarLayer
@onready var _near_layer: Sprite2D = $NearLayer

var _platform: Node2D
var _viewport_center: Vector2


func _ready() -> void:
	_platform = get_node_or_null(platform_path) as Node2D
	assert(_platform != null, "ParallaxSceneBackground requires a platform Node2D")
	assert(_far_layer.texture != null, "Far parallax texture is required")
	assert(_near_layer.texture != null, "Near parallax texture is required")
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()
	_update_layer_positions()


func _process(_delta: float) -> void:
	_update_layer_positions()


func _update_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_viewport_center = viewport_size * 0.5
	_fit_layer_to_viewport(_far_layer, viewport_size)
	_fit_layer_to_viewport(_near_layer, viewport_size)
	_update_layer_positions()


func _fit_layer_to_viewport(layer_sprite: Sprite2D, viewport_size: Vector2) -> void:
	var texture_size: Vector2 = layer_sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var cover_scale: float = maxf(
		viewport_size.x / texture_size.x,
		viewport_size.y / texture_size.y
	)
	layer_sprite.scale = Vector2.ONE * cover_scale * overscan_ratio


func _update_layer_positions() -> void:
	if _platform == null:
		return
	_far_layer.position = Vector2(
		_viewport_center.x - _platform.position.x * far_motion_scale,
		_viewport_center.y
	)
	_near_layer.position = Vector2(
		_viewport_center.x - _platform.position.x * near_motion_scale,
		_viewport_center.y
	)
