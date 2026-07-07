class_name ParallaxSceneBackground
extends CanvasLayer

@export_node_path("Node2D") var platform_path: NodePath
@export_range(0.0, 1.0, 0.001) var scene_motion_scale: float = 0.055
@export_range(1.0, 2.0, 0.01) var overscan_ratio: float = 1.25

@onready var _scene_one_layer: Sprite2D = $SceneOneLayer
@onready var _scene_two_layer: Sprite2D = $SceneTwoLayer

static var _next_scene_index: int = 0

var _scene_layers: Array[Sprite2D] = []
var _active_scene_index: int = 0
var _platform: Node2D
var _viewport_center: Vector2


func _ready() -> void:
	_scene_layers = [_scene_one_layer, _scene_two_layer]
	_platform = get_node_or_null(platform_path) as Node2D
	assert(_platform != null, "ParallaxSceneBackground requires a platform Node2D")
	for layer_sprite: Sprite2D in _scene_layers:
		assert(layer_sprite.texture != null, "Scene background texture is required")
	_select_scene_for_run()
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()
	_update_layer_positions()


func _process(_delta: float) -> void:
	_update_layer_positions()


func get_active_scene_index_for_tests() -> int:
	return _active_scene_index


func get_visible_scene_layer_count_for_tests() -> int:
	var count: int = 0
	for layer_sprite: Sprite2D in _scene_layers:
		if layer_sprite.visible:
			count += 1
	return count


func get_scene_layer_alpha_for_tests(scene_index: int) -> float:
	if scene_index < 0 or scene_index >= _scene_layers.size():
		return -1.0
	return _scene_layers[scene_index].modulate.a


func get_active_scene_position_for_tests() -> Vector2:
	return _get_active_layer().position


func _select_scene_for_run() -> void:
	if _scene_layers.is_empty():
		_active_scene_index = 0
		return
	_active_scene_index = _next_scene_index % _scene_layers.size()
	_next_scene_index = (_next_scene_index + 1) % _scene_layers.size()
	for index: int in range(_scene_layers.size()):
		var layer_sprite: Sprite2D = _scene_layers[index]
		layer_sprite.visible = index == _active_scene_index
		layer_sprite.modulate = Color.WHITE


func _update_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_viewport_center = viewport_size * 0.5
	for layer_sprite: Sprite2D in _scene_layers:
		_fit_layer_to_viewport(layer_sprite, viewport_size)
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
	var position := Vector2(
		_viewport_center.x - _platform.position.x * scene_motion_scale,
		_viewport_center.y
	)
	for layer_sprite: Sprite2D in _scene_layers:
		layer_sprite.position = position


func _get_active_layer() -> Sprite2D:
	return _scene_layers[_active_scene_index]
