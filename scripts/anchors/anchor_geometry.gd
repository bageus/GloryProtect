class_name AnchorGeometry
extends RefCounted

var _platform: PlatformController
var _balance: AnchorBalance
var _orb_x: float
var _ground_y: float


func configure(
	platform: PlatformController,
	balance: AnchorBalance,
	orb_x: float,
	ground_y: float
) -> void:
	_platform = platform
	_balance = balance
	_orb_x = orb_x
	_ground_y = ground_y


func is_in_installation_zone() -> bool:
	return absf(_platform.position.x - _orb_x) <= _balance.installation_zone_half_width


func get_ground_point(anchor_id: int) -> Vector2:
	return Vector2(_orb_x + _balance.ground_offsets[anchor_id], _ground_y)


func get_platform_attachment_local_x(anchor_id: int) -> float:
	var half_width := _platform.get_platform_width() * 0.5
	match anchor_id:
		0:
			return -half_width + _balance.platform_outer_inset
		1:
			return -half_width + _balance.platform_inner_inset
		2:
			return half_width - _balance.platform_inner_inset
		3:
			return half_width - _balance.platform_outer_inset
		_:
			return 0.0


func get_platform_attachment_world(anchor_id: int) -> Vector2:
	return Vector2(
		_platform.position.x + get_platform_attachment_local_x(anchor_id),
		_platform.position.y
			+ _platform.platform_height * _balance.platform_attachment_y_factor
	)


func is_within_rope_length(anchor_id: int) -> bool:
	return (
		get_platform_attachment_world(anchor_id).distance_to(get_ground_point(anchor_id))
		<= _balance.rope_length
	)


func get_rope_boundary_min_x(anchor_id: int) -> float:
	return (
		get_ground_point(anchor_id).x
		- get_max_horizontal_rope_distance()
		- get_platform_attachment_local_x(anchor_id)
	)


func get_rope_boundary_max_x(anchor_id: int) -> float:
	return (
		get_ground_point(anchor_id).x
		+ get_max_horizontal_rope_distance()
		- get_platform_attachment_local_x(anchor_id)
	)


func get_directional_min_x(anchor: AnchorRuntime) -> float:
	if anchor.side == AnchorRuntime.Side.RIGHT:
		return anchor.attached_platform_x
	return get_rope_boundary_min_x(anchor.anchor_id)


func get_directional_max_x(anchor: AnchorRuntime) -> float:
	if anchor.side == AnchorRuntime.Side.LEFT:
		return anchor.attached_platform_x
	return get_rope_boundary_max_x(anchor.anchor_id)


func get_max_horizontal_rope_distance() -> float:
	var attachment_y := (
		_platform.position.y
		+ _platform.platform_height * _balance.platform_attachment_y_factor
	)
	var vertical_distance := absf(_ground_y - attachment_y)
	var squared_horizontal := (
		_balance.rope_length * _balance.rope_length
		- vertical_distance * vertical_distance
	)
	return sqrt(maxf(0.0, squared_horizontal))
