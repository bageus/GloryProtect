class_name PlatformUpgradeAssetOverlayStabilityFixed
extends PlatformUpgradeAssetOverlay

const FIXED_STABILITY_BASE: Texture2D = preload(
	"res://visual/objects/platform/core/stability/stability.png"
)
const FIXED_STABILITY_FLAME_1: Texture2D = preload(
	"res://visual/objects/platform/core/stability/overlay_stability_01.png"
)
const FIXED_STABILITY_FLAME_2: Texture2D = preload(
	"res://visual/objects/platform/core/stability/overlay_stability_02.png"
)
const FIXED_STABILITY_FLAME_3: Texture2D = preload(
	"res://visual/objects/platform/core/stability/overlay_stability_03.png"
)
const WIND_COMPENSATOR_BASE: Texture2D = preload(
	"res://visual/objects/platform/core/asset_air_02.png"
)
const WIND_COMPENSATOR_ACTIVE: Texture2D = preload(
	"res://visual/objects/platform/core/asset_air_01.png"
)

@export_node_path("PlatformVisualController") var platform_visual_path: NodePath = NodePath(
	"../PlatformVisualController"
)
@export_node_path("WindSystem") var wind_system_path: NodePath = NodePath(
	"../../../WindSystem"
)

@export_range(0.0, 32.0, 0.25) var stability_edge_overlap: float = 6.0
@export_range(-64.0, 64.0, 0.25) var stability_vertical_offset: float = 0.0
@export_range(0.0, 32.0, 0.25) var stability_overlay_bottom_padding: float = 0.0
@export_range(-48.0, 48.0, 0.25) var control_under_driver_offset_x: float = 3.0
@export_range(-24.0, 48.0, 0.25) var control_under_driver_gap: float = 0.0
@export_range(-16.0, 16.0, 0.25) var control_active_offset_x: float = -2.0
@export_range(0.0, 16.0, 0.25) var control_active_lift_y: float = 3.0
@export var wind_compensator_size: Vector2 = Vector2(56.0, 42.0)
@export var wind_compensator_offset: Vector2 = Vector2(92.0, 25.0)

var _fixed_stability_flames: Array[Texture2D] = [
	FIXED_STABILITY_FLAME_1,
	FIXED_STABILITY_FLAME_2,
	FIXED_STABILITY_FLAME_3,
]

@onready var _platform_visual: PlatformVisualController = get_node_or_null(
	platform_visual_path
) as PlatformVisualController
@onready var _wind: WindSystem = get_node_or_null(wind_system_path) as WindSystem


func _draw() -> void:
	_draw_speed_assets()
	_draw_stability_assets()
	_draw_core_overlay()
	_draw_control_mechanism()
	_draw_wind_compensators()


func get_visible_asset_ids_for_tests() -> PackedStringArray:
	var result: PackedStringArray = super.get_visible_asset_ids_for_tests()
	if is_wind_compensator_visible_for_tests():
		result.append("wind_compensator")
	return result


func get_stability_base_centers_for_tests() -> Array[Vector2]:
	return [
		_get_stability_layout(-1, FIXED_STABILITY_FLAME_1)["base_center"],
		_get_stability_layout(1, FIXED_STABILITY_FLAME_1)["base_center"],
	]


func get_stability_base_draw_size_for_tests() -> Vector2:
	return _get_stability_layout(1, FIXED_STABILITY_FLAME_1)["base_size"]


func get_stability_overlay_center_for_tests(side: int) -> Vector2:
	return _get_stability_layout(side, FIXED_STABILITY_FLAME_1)["overlay_center"]


func get_stability_overlay_draw_size_for_tests() -> Vector2:
	return _get_stability_layout(1, FIXED_STABILITY_FLAME_1)["overlay_size"]


func get_stability_base_scale_for_tests() -> float:
	return _get_stability_layout(1, FIXED_STABILITY_FLAME_1)["base_scale"]


func get_platform_edge_x_for_tests(side: int) -> float:
	return _get_platform_edge_x(side)


func get_control_under_driver_offset_x_for_tests() -> float:
	return control_under_driver_offset_x


func get_control_under_driver_gap_for_tests() -> float:
	return control_under_driver_gap


func get_control_active_offset_x_for_tests() -> float:
	return control_active_offset_x


func get_control_active_lift_y_for_tests() -> float:
	return control_active_lift_y


func is_wind_compensator_visible_for_tests() -> bool:
	return _anchorless != null and _anchorless.upgrades.wind_reduction_ratio > 0.0


func get_wind_compensator_centers_for_tests() -> Array[Vector2]:
	return [_get_wind_compensator_center(-1), _get_wind_compensator_center(1)]


func get_wind_compensator_active_side_for_tests() -> int:
	if not is_wind_compensator_visible_for_tests():
		return 0
	if _wind == null or is_zero_approx(_wind.get_current_force()):
		return 0
	return 1 if _wind.get_current_force() > 0.0 else -1


func is_stability_side_mirrored_for_tests(side: int) -> bool:
	return side < 0


func _draw_stability_assets() -> void:
	if not is_stability_asset_visible():
		return
	var active_side: int = _last_direction
	var active_frame: Texture2D = _get_frame(_fixed_stability_flames)
	for side: int in [-1, 1]:
		var layout: Dictionary = _get_stability_layout(side, active_frame)
		_draw_stability_texture(
			FIXED_STABILITY_BASE,
			layout["base_source"],
			layout["base_center"],
			layout["base_size"],
			layout["mirrored"]
		)
		if is_stability_pulse_active_for_tests() and active_side == side:
			_draw_stability_texture(
				active_frame,
				layout["overlay_source"],
				layout["overlay_center"],
				layout["overlay_size"],
				layout["mirrored"]
			)


func _draw_wind_compensators() -> void:
	if not is_wind_compensator_visible_for_tests():
		return
	var active_side: int = get_wind_compensator_active_side_for_tests()
	for side: int in [-1, 1]:
		var texture: Texture2D = WIND_COMPENSATOR_ACTIVE if active_side == side else WIND_COMPENSATOR_BASE
		_draw_texture_centered(
			texture,
			_get_wind_compensator_center(side),
			wind_compensator_size,
			side < 0
		)


func _get_all_textures() -> Array[Texture2D]:
	var textures: Array[Texture2D] = super._get_all_textures()
	textures.append(FIXED_STABILITY_BASE)
	textures.append(FIXED_STABILITY_FLAME_1)
	textures.append(FIXED_STABILITY_FLAME_2)
	textures.append(FIXED_STABILITY_FLAME_3)
	textures.append(WIND_COMPENSATOR_BASE)
	textures.append(WIND_COMPENSATOR_ACTIVE)
	return textures


func _get_control_base_center() -> Vector2:
	var platform_top: float = _get_platform_surface_y()
	return Vector2(
		_get_control_post_center_x() + control_under_driver_offset_x,
		platform_top + control_under_driver_gap + control_mechanism_size.y * 0.5
	)


func _get_control_active_center() -> Vector2:
	return super._get_control_active_center() + Vector2(
		control_active_offset_x,
		-control_active_lift_y
	)


func _get_control_post_center_x() -> float:
	if _platform_visual == null:
		return 0.0
	return _platform_visual.driver_console_surface_offset.x


func _get_wind_compensator_center(side: int) -> Vector2:
	var normalized_side: int = -1 if side < 0 else 1
	return Vector2(
		wind_compensator_offset.x * float(normalized_side),
		wind_compensator_offset.y
	)


func _get_stability_layout(side: int, overlay_texture: Texture2D) -> Dictionary:
	var normalized_side: int = -1 if side < 0 else 1
	var base_source: Rect2 = _source_rects.get(FIXED_STABILITY_BASE, Rect2())
	var overlay_source: Rect2 = _source_rects.get(overlay_texture, Rect2())
	var base_scale: float = _get_stability_base_scale(base_source)
	var base_size: Vector2 = base_source.size * base_scale
	var overlay_size: Vector2 = overlay_source.size * base_scale
	var base_center: Vector2 = _get_stability_base_center(
		normalized_side,
		base_size
	)
	var overlay_center := Vector2(
		base_center.x,
		base_center.y
			+ base_size.y * 0.5
			- overlay_size.y * 0.5
			- stability_overlay_bottom_padding
	)
	return {
		"base_source": base_source,
		"overlay_source": overlay_source,
		"base_center": base_center,
		"overlay_center": overlay_center,
		"base_size": base_size,
		"overlay_size": overlay_size,
		"base_scale": base_scale,
		"mirrored": normalized_side < 0,
	}


func _get_stability_base_scale(base_source: Rect2) -> float:
	if base_source.size.x <= 0.0 or base_source.size.y <= 0.0:
		return 0.0
	return minf(
		stability_unit_size.x / base_source.size.x,
		stability_unit_size.y / base_source.size.y
	)


func _get_stability_base_center(side: int, base_size: Vector2) -> Vector2:
	var edge_x: float = _get_platform_edge_x(side)
	return Vector2(
		edge_x + float(side) * (base_size.x * 0.5 - stability_edge_overlap),
		stability_vertical_offset
	)


func _get_platform_edge_x(side: int) -> float:
	var normalized_side: int = -1 if side < 0 else 1
	if _platform == null or _platform.balance == null:
		return stability_unit_offset.x * float(normalized_side)
	return _platform.get_platform_width() * 0.5 * float(normalized_side)


func _draw_stability_texture(
	texture: Texture2D,
	source_rect: Rect2,
	center: Vector2,
	draw_size: Vector2,
	mirrored: bool
) -> void:
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return
	var rect := Rect2(-draw_size * 0.5, draw_size)
	var scale := Vector2(-1.0, 1.0) if mirrored else Vector2.ONE
	draw_set_transform(center, 0.0, scale)
	draw_texture_rect_region(texture, rect, source_rect)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
