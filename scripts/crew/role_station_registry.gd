class_name RoleStationRegistry
extends RefCounted

const DRIVER_CELL_INDEX: int = 10

var _platform: PlatformController
var _owners: Dictionary[StringName, int] = {}
var _dynamic_targets: Dictionary[StringName, float] = {}


func configure(platform: PlatformController) -> void:
	_platform = platform


func set_dynamic_target(
	role_id: int,
	station_id: int,
	local_x: float
) -> void:
	_dynamic_targets[_make_key(role_id, station_id)] = local_x


func clear_dynamic_target(role_id: int, station_id: int) -> void:
	var key: StringName = _make_key(role_id, station_id)
	_dynamic_targets.erase(key)
	_owners.erase(key)


func has_station(role_id: int, station_id: int = -1) -> bool:
	if not CrewRole.is_fixed_station(role_id):
		return true
	if role_id == CrewRole.Id.MEDIC or role_id == CrewRole.Id.TURRET:
		return _dynamic_targets.has(_make_key(role_id, station_id))
	return true


func reserve(role_id: int, station_id: int, defender_id: int) -> bool:
	if not CrewRole.is_fixed_station(role_id):
		return true
	if not has_station(role_id, station_id):
		return false
	var key: StringName = _make_key(role_id, station_id)
	if _owners.has(key) and _owners[key] != defender_id:
		return false
	_owners[key] = defender_id
	return true


func release(role_id: int, station_id: int, defender_id: int) -> void:
	if not CrewRole.is_fixed_station(role_id):
		return
	var key: StringName = _make_key(role_id, station_id)
	if _owners.get(key, -1) == defender_id:
		_owners.erase(key)


func get_owner(role_id: int, station_id: int = -1) -> int:
	return int(_owners.get(_make_key(role_id, station_id), -1))


func get_target_x(
	role_id: int,
	station_id: int,
	defender_id: int
) -> float:
	var key: StringName = _make_key(role_id, station_id)
	if _dynamic_targets.has(key):
		return float(_dynamic_targets[key])
	var platform_width := _platform.get_platform_width()
	var post_offset := (
		platform_width * 0.5
		- _platform.balance.cell_width * _platform.balance.anchor_post_cell_inset
	)
	match role_id:
		CrewRole.Id.DRIVER:
			return _platform.get_cell_local_x(DRIVER_CELL_INDEX)
		CrewRole.Id.LEFT_ANCHOR:
			return -post_offset
		CrewRole.Id.RIGHT_ANCHOR:
			return post_offset
		_:
			return float(defender_id - 1) * _platform.balance.cell_width


func _make_key(role_id: int, station_id: int) -> StringName:
	return StringName("%d:%d" % [role_id, station_id])
