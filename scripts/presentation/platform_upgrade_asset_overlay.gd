class_name PlatformUpgradeAssetOverlay
extends Node2D

const CORE_BORDER_DISTRIBUTED: Texture2D = preload(
	"res://visual/objects/platform/core/asset_platform_core_border_01.png"
)
const CORE_BORDER_FOCUSED: Texture2D = preload(
	"res://visual/objects/platform/core/asset_platform_core_border_02.png"
)
const CORE_SURGE_SPLASH: Texture2D = preload(
	"res://visual/objects/platform/core/asset_core_energy_splash.png"
)
const SPEED_ENGINE: Texture2D = preload(
	"res://visual/objects/platform/core/moovespeed/moovespeed.png"
)
const SPEED_FLAME_1: Texture2D = preload(
	"res://visual/objects/platform/core/moovespeed/overlay_moovespeed_01.png"
)
const SPEED_FLAME_2: Texture2D = preload(
	"res://visual/objects/platform/core/moovespeed/overlay_moovespeed_02.png"
)
const SPEED_FLAME_3: Texture2D = preload(
	"res://visual/objects/platform/core/moovespeed/overlay_moovespeed_03.png"
)
const CONTROL_BASE: Texture2D = preload(
	"res://visual/objects/platform/core/control_mechanism/control_mechanism_01.png"
)
const CONTROL_ACTIVE: Texture2D = preload(
	"res://visual/objects/platform/core/control_mechanism/control_mechanism_02.png"
)
const STABILITY_BASE: Texture2D = preload(
	"res://visual/objects/platform/core/control_stability/stability_control.png"
)
const STABILITY_FLAME_1: Texture2D = preload(
	"res://visual/objects/platform/core/control_stability/overlay_stability_control_01.png"
)
const STABILITY_FLAME_2: Texture2D = preload(
	"res://visual/objects/platform/core/control_stability/overlay_stability_control_02.png"
)
const STABILITY_FLAME_3: Texture2D = preload(
	"res://visual/objects/platform/core/control_stability/overlay_stability_control_03.png"
)
const WIND_COMPENSATOR_BASE: Texture2D = preload(
	"res://visual/objects/platform/core/asset_air_02.png"
)
const WIND_COMPENSATOR_ACTIVE: Texture2D = preload(
	"res://visual/objects/platform/core/asset_air_01.png"
)

const SPEED_ENGINE_BASE_SIZE: Vector2 = Vector2(64.8, 50.4)
const SPEED_ENGINE_SCALE_MULTIPLIER: float = 1.15

@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("ShieldCoreSystem") var shield_core_system_path: NodePath
@export_node_path("AnchorlessControlSystem") var anchorless_control_system_path: NodePath
@export_node_path("SteeringInputProvider") var steering_input_path: NodePath
@export_node_path("WindSystem") var wind_system_path: NodePath = NodePath(
	"../../../WindSystem"
)
@export_node_path("GroundOrbRegistry") var orb_registry_path: NodePath = NodePath(
	"../../GroundOrbRegistry"
)
@export_node_path("OrbContactSystem") var contact_system_path: NodePath = NodePath(
	"../../OrbContactSystem"
)

@export_range(0.0, 1.0, 0.01) var alpha_crop_threshold: float = 0.08
@export_range(1, 128, 1) var minimum_z_index: int = 12
@export var snap_visuals_to_canvas_pixels: bool = true
@export var platform_core_reference_size: Vector2 = Vector2(92.0, 92.0)
@export_range(0.0, 1.0, 0.01) var platform_core_protrusion_ratio: float = 0.38
@export var platform_core_reference_offset: Vector2 = Vector2(0.0, 12.0)
@export var core_overlay_size: Vector2 = Vector2(116.0, 116.0)
@export_range(1.0, 1.5, 0.01) var distributed_core_overlay_scale: float = 1.11
@export_range(0.1, 1.0, 0.01) var focused_core_overlay_scale: float = 0.75
@export var core_overlay_offset: Vector2 = Vector2.ZERO
@export var speed_engine_size: Vector2 = Vector2(74.52, 57.96)
@export var speed_engine_offset: Vector2 = Vector2(68.0, 0.0)
@export var control_mechanism_size: Vector2 = Vector2(58.0, 42.0)
@export var control_active_size: Vector2 = Vector2(34.0, 26.0)
@export var control_mechanism_surface_offset: Vector2 = Vector2(118.0, 5.0)
@export_range(-16.0, 16.0, 0.25) var control_active_gap: float = -2.0
@export_range(0.0, 16.0, 0.25) var control_active_amplitude: float = 4.0
@export_range(1.0, 18.0, 0.25) var control_active_speed: float = 5.0
@export var stability_unit_size: Vector2 = Vector2(44.0, 36.0)
@export var stability_unit_offset: Vector2 = Vector2(114.0, 34.0)
@export_range(0.05, 1.2, 0.05) var stability_pulse_duration: float = 0.45
@export var wind_compensator_size: Vector2 = Vector2(72.0, 54.0)
@export_range(0.0, 48.0, 0.25) var wind_compensator_gap: float = 8.0
@export_range(-64.0, 64.0, 0.25) var wind_compensator_vertical_offset: float = -8.0
@export_range(1.0, 24.0, 0.5) var overlay_frame_rate: float = 12.0

var _elapsed: float = 0.0
var _stability_pulse_elapsed: float = INF
var _last_direction: int = 0

var _source_rects: Dictionary[Texture2D, Rect2] = {}
var _speed_flames: Array[Texture2D] = [SPEED_FLAME_1, SPEED_FLAME_2, SPEED_FLAME_3]
var _stability_flames: Array[Texture2D] = [
	STABILITY_FLAME_1,
	STABILITY_FLAME_2,
	STABILITY_FLAME_3,
]

@onready var _platform: PlatformController = get_node(platform_path)
@onready var _shield_core: ShieldCoreSystem = get_node_or_null(
	shield_core_system_path
) as ShieldCoreSystem
@onready var _anchorless: AnchorlessControlSystem = get_node_or_null(
	anchorless_control_system_path
) as AnchorlessControlSystem
@onready var _steering: SteeringInputProvider = get_node_or_null(
	steering_input_path
) as SteeringInputProvider
@onready var _wind: WindSystem = get_node_or_null(wind_system_path) as WindSystem
@onready var _orb_registry: GroundOrbRegistry = get_node_or_null(
	orb_registry_path
) as GroundOrbRegistry
@onready var _contact: OrbContactSystem = get_node_or_null(
	contact_system_path
) as OrbContactSystem


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_as_relative = false
	z_index = maxi(z_index, minimum_z_index)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for texture: Texture2D in _get_all_textures():
		_source_rects[texture] = _get_safe_source_rect(texture)
	_resolve_optional_systems()
	_apply_canvas_pixel_snap()
	queue_redraw()


func _process(delta: float) -> void:
	_apply_canvas_pixel_snap()
	_resolve_optional_systems()
	var safe_delta: float = maxf(0.0, delta)
	_elapsed += safe_delta
	_update_direction_pulse(safe_delta)
	queue_redraw()


func _draw() -> void:
	_draw_speed_assets()
	_draw_stability_assets()
	_draw_core_overlay()
	_draw_control_mechanism()
	_draw_wind_compensators()


func get_visible_asset_ids_for_tests() -> PackedStringArray:
	var result := PackedStringArray()
	var core_asset: StringName = get_core_overlay_asset_for_tests()
	if core_asset != &"":
		result.append(String(core_asset))
	if is_speed_asset_visible():
		result.append("speed")
	if is_control_mechanism_visible():
		result.append("control")
	if is_stability_asset_visible():
		result.append("stability")
	if is_wind_compensator_visible_for_tests():
		result.append("wind_compensator")
	return result


func get_core_overlay_asset_for_tests() -> StringName:
	if _shield_core == null:
		return &""
	if _shield_core.upgrades.has_distributed_specialization():
		return &"distributed_border"
	if _shield_core.upgrades.has_focused_specialization():
		return &"focused_border"
	if _shield_core.upgrades.has_surge_specialization():
		return &"surge_splash"
	return &""


func get_platform_core_center_for_tests() -> Vector2:
	return _get_platform_core_center()


func get_core_overlay_center_for_tests() -> Vector2:
	return _get_platform_core_center() + core_overlay_offset


func get_core_overlay_draw_size_for_tests() -> Vector2:
	return _get_core_overlay_draw_size()


func get_core_overlay_rotation_for_tests() -> float:
	return _get_core_overlay_rotation()


func get_core_overlay_beam_direction_for_tests() -> Vector2:
	return _get_core_overlay_beam_direction()


func get_distributed_core_overlay_scale_for_tests() -> float:
	return distributed_core_overlay_scale


func get_focused_core_overlay_scale_for_tests() -> float:
	return focused_core_overlay_scale


func is_speed_asset_visible() -> bool:
	return _anchorless != null and _anchorless.upgrades.has_speed_specialization()


func get_speed_engine_count_for_tests() -> int:
	return 2 if is_speed_asset_visible() else 0


func get_speed_engine_base_size_for_tests() -> Vector2:
	return SPEED_ENGINE_BASE_SIZE


func get_speed_engine_scale_multiplier_for_tests() -> float:
	return SPEED_ENGINE_SCALE_MULTIPLIER


func get_speed_engine_size_for_tests() -> Vector2:
	return speed_engine_size


func get_speed_flame_size_for_tests() -> Vector2:
	return speed_engine_size


func get_speed_engine_offset_for_tests() -> Vector2:
	return speed_engine_offset


func get_speed_engine_centers_for_tests() -> Array[Vector2]:
	return [
		_get_speed_asset_center(-1),
		_get_speed_asset_center(1),
	]


func get_active_speed_flame_side_for_tests() -> int:
	if not is_speed_asset_visible():
		return 0
	var direction: int = _get_motion_direction()
	if direction == 0:
		return 0
	return -direction


func is_control_mechanism_visible() -> bool:
	return (
		_anchorless != null
		and (
			_anchorless.upgrades.steering_force_bonus_ratio > 0.0
			or _anchorless.upgrades.automatic_steering_enabled
		)
	)


func get_control_base_center_for_tests() -> Vector2:
	return _get_control_base_center()


func get_control_active_center_for_tests() -> Vector2:
	return _get_control_active_center()


func is_stability_asset_visible() -> bool:
	return (
		_anchorless != null
		and (
			_anchorless.upgrades.has_precise_specialization()
			or _anchorless.upgrades.release_drag_bonus_ratio > 0.0
		)
	)


func is_stability_pulse_active_for_tests() -> bool:
	return _stability_pulse_elapsed < stability_pulse_duration


func is_wind_compensator_visible_for_tests() -> bool:
	return _anchorless != null and _anchorless.upgrades.wind_reduction_ratio > 0.0


func get_wind_compensator_centers_for_tests() -> Array[Vector2]:
	return [_get_wind_compensator_center(-1), _get_wind_compensator_center(1)]


func get_wind_compensator_draw_size_for_tests() -> Vector2:
	return _get_draw_size(WIND_COMPENSATOR_BASE, wind_compensator_size)


func get_wind_compensator_active_side_for_tests() -> int:
	if not is_wind_compensator_visible_for_tests():
		return 0
	if _wind == null or is_zero_approx(_wind.get_current_force()):
		return 0
	return 1 if _wind.get_current_force() > 0.0 else -1


func debug_trigger_direction_change_for_tests(direction: int) -> void:
	if direction == 0:
		return
	_last_direction = 1 if direction > 0 else -1
	_stability_pulse_elapsed = 0.0
	queue_redraw()


func _draw_core_overlay() -> void:
	var texture: Texture2D = null
	match get_core_overlay_asset_for_tests():
		&"distributed_border":
			texture = CORE_BORDER_DISTRIBUTED
		&"focused_border":
			texture = CORE_BORDER_FOCUSED
		&"surge_splash":
			texture = CORE_SURGE_SPLASH
	if texture == null:
		return
	_draw_texture_centered(
		texture,
		_get_platform_core_center() + core_overlay_offset,
		_get_core_overlay_draw_size(),
		false,
		_get_core_overlay_rotation()
	)


func _get_core_overlay_draw_size() -> Vector2:
	match get_core_overlay_asset_for_tests():
		&"distributed_border":
			return core_overlay_size * distributed_core_overlay_scale
		&"focused_border":
			return core_overlay_size * focused_core_overlay_scale
		_:
			return core_overlay_size


func _get_core_overlay_rotation() -> float:
	if get_core_overlay_asset_for_tests() != &"surge_splash":
		return 0.0
	var direction: Vector2 = _get_core_overlay_beam_direction()
	if direction.length_squared() <= 0.01:
		return 0.0
	return direction.angle() - PI * 0.5


func _get_core_overlay_beam_direction() -> Vector2:
	if _contact == null or _orb_registry == null:
		return Vector2.ZERO
	var orb_id: int = _contact.get_active_orb_id()
	if orb_id < 0:
		return Vector2.ZERO
	var core_world_position: Vector2 = to_global(
		_get_platform_core_center() + core_overlay_offset
	)
	var orb_world_position: Vector2 = _orb_registry.get_orb_world_position(orb_id)
	var direction: Vector2 = orb_world_position - core_world_position
	if direction.length_squared() <= 0.01:
		return Vector2.ZERO
	return direction.normalized()


func _draw_speed_assets() -> void:
	if not is_speed_asset_visible():
		return
	var flame_side: int = get_active_speed_flame_side_for_tests()
	for side: int in [-1, 1]:
		var center: Vector2 = _get_speed_asset_center(side)
		_draw_texture_centered(SPEED_ENGINE, center, speed_engine_size, side < 0)
		if flame_side == side:
			_draw_texture_centered(
				_get_frame(_speed_flames),
				center,
				speed_engine_size,
				side < 0
			)


func _draw_control_mechanism() -> void:
	if not is_control_mechanism_visible():
		return
	_draw_texture_centered(
		CONTROL_BASE,
		_get_control_base_center(),
		control_mechanism_size,
		false
	)
	_draw_texture_centered(
		CONTROL_ACTIVE,
		_get_control_active_center(),
		control_active_size,
		false
	)


func _draw_stability_assets() -> void:
	if not is_stability_asset_visible():
		return
	var active_side: int = _last_direction
	for side: int in [-1, 1]:
		var center := Vector2(stability_unit_offset.x * float(side), stability_unit_offset.y)
		_draw_texture_centered(STABILITY_BASE, center, stability_unit_size, side < 0)
		if is_stability_pulse_active_for_tests() and active_side == side:
			_draw_texture_centered(
				_get_frame(_stability_flames),
				center,
				stability_unit_size,
				side < 0
			)


func _draw_wind_compensators() -> void:
	if not is_wind_compensator_visible_for_tests():
		return
	var active_side: int = get_wind_compensator_active_side_for_tests()
	for side: int in [-1, 1]:
		var texture: Texture2D = (
			WIND_COMPENSATOR_ACTIVE
			if active_side == side
			else WIND_COMPENSATOR_BASE
		)
		_draw_texture_centered(
			texture,
			_get_wind_compensator_center(side),
			wind_compensator_size,
			side < 0
		)


func _draw_texture_centered(
	texture: Texture2D,
	center: Vector2,
	target_size: Vector2,
	mirrored: bool,
	rotation: float = 0.0
) -> void:
	var draw_size: Vector2 = _get_draw_size(texture, target_size)
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return
	var source_rect: Rect2 = _source_rects.get(texture, Rect2())
	var rect := Rect2(-draw_size * 0.5, draw_size)
	var scale := Vector2(-1.0, 1.0) if mirrored else Vector2.ONE
	draw_set_transform(center, rotation, scale)
	draw_texture_rect_region(texture, rect, source_rect)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _get_draw_size(texture: Texture2D, target_size: Vector2) -> Vector2:
	var source_rect: Rect2 = _source_rects.get(texture, Rect2())
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return Vector2.ZERO
	return TextureRegionLayout.fit_inside(source_rect.size, target_size)


func _get_safe_source_rect(texture: Texture2D) -> Rect2:
	var source_rect: Rect2 = TextureRegionLayout.get_alpha_bounds(
		texture,
		alpha_crop_threshold
	)
	if source_rect.size.x > 0.0 and source_rect.size.y > 0.0:
		return source_rect
	return Rect2(Vector2.ZERO, texture.get_size())


func _update_direction_pulse(delta: float) -> void:
	if _stability_pulse_elapsed < stability_pulse_duration:
		_stability_pulse_elapsed += delta
	if not is_stability_asset_visible():
		_last_direction = 0
		return
	var direction: int = _get_motion_direction()
	if direction == 0:
		return
	if _last_direction != 0 and _last_direction != direction:
		_stability_pulse_elapsed = 0.0
	_last_direction = direction


func _get_motion_direction() -> int:
	if _platform == null:
		return 0
	if absf(_platform.horizontal_velocity) > 1.0:
		return int(signf(_platform.horizontal_velocity))
	if _steering != null:
		var axis: float = _steering.get_steering_axis()
		if absf(axis) > 0.01:
			return int(signf(axis))
	return 0


func _get_speed_asset_center(side: int) -> Vector2:
	return _get_platform_core_center() + Vector2(
		speed_engine_offset.x * float(side),
		speed_engine_offset.y
	)


func _get_control_base_center() -> Vector2:
	return Vector2(
		control_mechanism_surface_offset.x,
		_get_platform_surface_y()
			+ control_mechanism_surface_offset.y
			- control_mechanism_size.y * 0.5
	)


func _get_control_active_center() -> Vector2:
	return _get_control_base_center() + _get_control_active_rest_offset() + Vector2(
		sin(_elapsed * control_active_speed) * control_active_amplitude,
		0.0
	)


func _get_control_active_rest_offset() -> Vector2:
	return Vector2(
		control_mechanism_size.x * 0.5
			+ control_active_size.x * 0.5
			+ control_active_gap,
		(control_mechanism_size.y - control_active_size.y) * 0.5
	)


func _get_wind_compensator_center(side: int) -> Vector2:
	var normalized_side: int = -1 if side < 0 else 1
	var draw_size: Vector2 = get_wind_compensator_draw_size_for_tests()
	var inner_edge_x: float = _get_anchor_post_inner_edge_x(normalized_side)
	return Vector2(
		inner_edge_x
			- float(normalized_side) * (wind_compensator_gap + draw_size.x * 0.5),
		_get_platform_surface_y() + draw_size.y * 0.5 + wind_compensator_vertical_offset
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


func _get_platform_surface_y() -> float:
	if _platform == null or _platform.balance == null:
		return -29.0
	return -_platform.balance.platform_height * 0.5


func _get_platform_core_center() -> Vector2:
	if _platform == null or _platform.balance == null:
		return platform_core_reference_offset
	var reference_size: Vector2 = platform_core_reference_size
	var platform_bottom: float = _platform.balance.platform_height * 0.5
	var core_center_y: float = (
		platform_bottom
		+ (platform_core_protrusion_ratio - 0.5) * reference_size.y
	)
	return Vector2(0.0, core_center_y) + platform_core_reference_offset


func _get_frame(frames: Array[Texture2D]) -> Texture2D:
	var index: int = floori(_elapsed * overlay_frame_rate) % frames.size()
	return frames[index]


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


func _resolve_optional_systems() -> void:
	if _shield_core == null:
		_shield_core = get_node_or_null(shield_core_system_path) as ShieldCoreSystem
		if _shield_core != null and not _shield_core.upgrades_changed.is_connected(_on_upgrade_changed):
			_shield_core.upgrades_changed.connect(_on_upgrade_changed)
	if _anchorless == null:
		_anchorless = get_node_or_null(anchorless_control_system_path) as AnchorlessControlSystem
		if _anchorless != null and not _anchorless.upgrades_changed.is_connected(_on_upgrade_changed):
			_anchorless.upgrades_changed.connect(_on_upgrade_changed)
	if _wind == null:
		_wind = get_node_or_null(wind_system_path) as WindSystem
		if _wind != null and not _wind.wind_state_changed.is_connected(_on_upgrade_changed):
			_wind.wind_state_changed.connect(_on_upgrade_changed)
	if _orb_registry == null:
		_orb_registry = get_node_or_null(orb_registry_path) as GroundOrbRegistry
	if _contact == null:
		_contact = get_node_or_null(contact_system_path) as OrbContactSystem


func _get_all_textures() -> Array[Texture2D]:
	return [
		CORE_BORDER_DISTRIBUTED,
		CORE_BORDER_FOCUSED,
		CORE_SURGE_SPLASH,
		SPEED_ENGINE,
		SPEED_FLAME_1,
		SPEED_FLAME_2,
		SPEED_FLAME_3,
		CONTROL_BASE,
		CONTROL_ACTIVE,
		STABILITY_BASE,
		STABILITY_FLAME_1,
		STABILITY_FLAME_2,
		STABILITY_FLAME_3,
		WIND_COMPENSATOR_BASE,
		WIND_COMPENSATOR_ACTIVE,
	]


func _on_upgrade_changed() -> void:
	queue_redraw()
