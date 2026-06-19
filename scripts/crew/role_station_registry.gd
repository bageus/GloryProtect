class_name RoleStationRegistry
extends RefCounted

var _platform: PlatformController
var _owners: Dictionary = {}


func configure(platform: PlatformController) -> void:
	_platform = platform


func reserve(role_id: int, defender_id: int) -> bool:
	if not CrewRole.is_fixed_station(role_id):
		return true
	if _owners.has(role_id) and _owners[role_id] != defender_id:
		return false
	_owners[role_id] = defender_id
	return true


func release(role_id: int, defender_id: int) -> void:
	if not CrewRole.is_fixed_station(role_id):
		return
	if _owners.get(role_id, -1) == defender_id:
		_owners.erase(role_id)


func get_owner(role_id: int) -> int:
	return int(_owners.get(role_id, -1))


func get_target_x(role_id: int, defender_id: int) -> float:
	var platform_width := _platform.get_platform_width()
	var post_offset := (
		platform_width * 0.5
		- _platform.balance.cell_width * _platform.balance.anchor_post_cell_inset
	)
	match role_id:
		CrewRole.Id.DRIVER:
			return 0.0
		CrewRole.Id.LEFT_ANCHOR:
			return -post_offset
		CrewRole.Id.RIGHT_ANCHOR:
			return post_offset
		_:
			return float(defender_id - 1) * _platform.balance.cell_width
