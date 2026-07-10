class_name PlatformUpgradeWindCompensatorAsset
extends Resource

@export var base_texture: Texture2D
@export var active_texture: Texture2D
@export var size: Vector2 = Vector2(72.0, 54.0)
@export_range(0.0, 48.0, 0.25) var gap: float = 8.0
@export_range(-64.0, 64.0, 0.25) var vertical_offset: float = 8.0


func is_visible(anchorless: AnchorlessControlSystem) -> bool:
	return anchorless != null and anchorless.upgrades.wind_reduction_ratio > 0.0


func get_active_side(
	anchorless: AnchorlessControlSystem,
	wind: WindSystem
) -> int:
	if not is_visible(anchorless):
		return 0
	if wind == null or is_zero_approx(wind.get_current_force()):
		return 0
	return 1 if wind.get_current_force() > 0.0 else -1


func get_texture_for_side(
	side: int,
	anchorless: AnchorlessControlSystem,
	wind: WindSystem
) -> Texture2D:
	if get_active_side(anchorless, wind) == side and active_texture != null:
		return active_texture
	return base_texture


func get_centers(
	platform: PlatformController,
	draw_size: Vector2
) -> Array[Vector2]:
	return [
		_get_center(platform, draw_size, -1),
		_get_center(platform, draw_size, 1),
	]


func get_draw_size(source_rects: Dictionary[Texture2D, Rect2]) -> Vector2:
	if base_texture == null:
		return Vector2.ZERO
	var source_rect: Rect2 = source_rects.get(base_texture, Rect2())
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return Vector2.ZERO
	return TextureRegionLayout.fit_inside(source_rect.size, size)


func append_textures(textures: Array[Texture2D]) -> void:
	if base_texture != null:
		textures.append(base_texture)
	if active_texture != null:
		textures.append(active_texture)


func _get_center(
	platform: PlatformController,
	draw_size: Vector2,
	side: int
) -> Vector2:
	var normalized_side: int = -1 if side < 0 else 1
	var inner_edge_x: float = _get_anchor_post_inner_edge_x(
		platform,
		normalized_side
	)
	return Vector2(
		inner_edge_x - float(normalized_side) * (gap + draw_size.x * 0.5),
		_get_platform_bottom_y(platform) + draw_size.y * 0.5 + vertical_offset
	)


func _get_anchor_post_inner_edge_x(
	platform: PlatformController,
	side: int
) -> float:
	var normalized_side: int = -1 if side < 0 else 1
	if platform == null or platform.balance == null:
		return 0.0
	if normalized_side < 0:
		var left_inner_post: int = mini(1, platform.get_cell_count() - 1)
		return (
			platform.get_cell_local_x(left_inner_post)
			+ platform.balance.anchor_post_width * 0.5
		)
	var right_inner_post: int = maxi(0, platform.get_cell_count() - 2)
	return (
		platform.get_cell_local_x(right_inner_post)
		- platform.balance.anchor_post_width * 0.5
	)


func _get_platform_bottom_y(platform: PlatformController) -> float:
	if platform == null or platform.balance == null:
		return 29.0
	return platform.balance.platform_height * 0.5
