class_name AnchorGeometry
extends RefCounted

var _platform: PlatformController
var _balance: AnchorBalance
var _registry: GroundOrbRegistry


func configure(
	platform: PlatformController,
	balance: AnchorBalance,
	registry: GroundOrbRegistry
) -> void:
	_platform = platform
	_balance = balance
	_registry = registry


func get_current_installation_orb_id() -> int:
	return _registry.get_installation_orb_at(
		_platform.position.x,
		_balance.installation_zone_half_width
	)


func is_in_installation_zone() -> bool:
	return get_current_installation_orb_id() >= 0


func is_orb_in_installation_zone(orb_id: int) -> bool:
	return _registry.is_platform_in_installation_zone(
		orb_id,
		_platform.position.x,
		_balance.installation_zone_half_width
	)


func get_ground_point_for_orb(orb_id: int, anchor_id: int) -> Vector2:
	return _registry.get_anchor_ground_point(
		orb_id,
		anchor_id,
		_balance.ground_offsets
	)


func get_current_silhouette_ground_point(anchor_id: int) -> Vector2:
	var orb_id := get_current_installation_orb_id()
	if orb_id < 0:
		return Vector2.ZERO
	return get_ground_point_for_orb(orb_id, anchor_id)


func get_runtime_ground_point(anchor: AnchorRuntime) -> Vector2:
	return anchor.get_active_ground_point()


func get_platform_attachment_local_x(anchor_id: int) -> float:
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


func get_platform_attachment_world(anchor_id: int) -> Vector2:
	return Vector2(
		_platform.position.x + get_platform_attachment_local_x(anchor_id),
		_platform.position.y
			+ _platform.get_platform_height() * _balance.platform_attachment_y_factor
	)


func is_within_rope_length(anchor: AnchorRuntime) -> bool:
	if not anchor.has_target():
		return false
	return (
		get_platform_attachment_world(anchor.anchor_id).distance_to(
			anchor.target_ground_point
		)
		<= _balance.rope_length
	)


func get_rope_boundary_min_x(anchor: AnchorRuntime) -> float:
	return (
		anchor.attached_ground_point.x
		- get_max_horizontal_rope_distance(anchor.attached_ground_point.y)
		- get_platform_attachment_local_x(anchor.anchor_id)
	)


func get_rope_boundary_max_x(anchor: AnchorRuntime) -> float:
	return (
		anchor.attached_ground_point.x
		+ get_max_horizontal_rope_distance(anchor.attached_ground_point.y)
		- get_platform_attachment_local_x(anchor.anchor_id)
	)


func get_directional_min_x(anchor: AnchorRuntime) -> float:
	if anchor.side == AnchorRuntime.Side.RIGHT:
		return anchor.attached_platform_x
	return get_rope_boundary_min_x(anchor)


func get_directional_max_x(anchor: AnchorRuntime) -> float:
	if anchor.side == AnchorRuntime.Side.LEFT:
		return anchor.attached_platform_x
	return get_rope_boundary_max_x(anchor)


func get_max_horizontal_rope_distance(ground_y: float) -> float:
	var attachment_y := (
		_platform.position.y
		+ _platform.get_platform_height() * _balance.platform_attachment_y_factor
	)
	var vertical_distance := absf(ground_y - attachment_y)
	var squared_horizontal := (
		_balance.rope_length * _balance.rope_length
		- vertical_distance * vertical_distance
	)
	return sqrt(maxf(0.0, squared_horizontal))
