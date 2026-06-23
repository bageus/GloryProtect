class_name GroundOrbRegistry
extends Node

@export var catalog: GroundOrbCatalog
@export var shield_balance: ShieldBalance


func _ready() -> void:
	assert(catalog != null, "GroundOrbRegistry requires GroundOrbCatalog")
	assert(shield_balance != null, "GroundOrbRegistry requires ShieldBalance")
	assert(
		catalog.get_orb_count() == shield_balance.section_count,
		"Ground orb count must match shield section count"
	)


func get_orb_count() -> int:
	return catalog.get_orb_count()


func is_valid_orb(orb_id: int) -> bool:
	return orb_id >= 0 and orb_id < get_orb_count()


func get_section_id(orb_id: int) -> int:
	assert(is_valid_orb(orb_id), "Invalid orb id: %d" % orb_id)
	return orb_id


func get_world_x(orb_id: int) -> float:
	assert(is_valid_orb(orb_id), "Invalid orb id: %d" % orb_id)
	return catalog.world_positions[orb_id]


func get_contact_half_width() -> float:
	return catalog.contact_half_width


func get_orb_world_position(orb_id: int) -> Vector2:
	return Vector2(
		get_world_x(orb_id),
		catalog.ground_y + catalog.orb_vertical_offset
	)


func get_anchor_ground_point(
	orb_id: int,
	anchor_id: int,
	ground_offsets: PackedFloat32Array
) -> Vector2:
	assert(anchor_id >= 0 and anchor_id < ground_offsets.size())
	return Vector2(
		get_world_x(orb_id) + ground_offsets[anchor_id],
		catalog.ground_y
	)


func get_contact_orb_at(platform_x: float) -> int:
	return _find_orb_in_range(platform_x, catalog.contact_half_width)


func get_installation_orb_at(platform_x: float, half_width: float) -> int:
	return _find_orb_in_range(platform_x, half_width)


func is_platform_in_contact(orb_id: int, platform_x: float) -> bool:
	if not is_valid_orb(orb_id):
		return false
	return absf(platform_x - get_world_x(orb_id)) <= catalog.contact_half_width


func is_platform_in_installation_zone(
	orb_id: int,
	platform_x: float,
	half_width: float
) -> bool:
	if not is_valid_orb(orb_id):
		return false
	return absf(platform_x - get_world_x(orb_id)) <= half_width


func _find_orb_in_range(platform_x: float, half_width: float) -> int:
	var nearest_id := -1
	var nearest_distance := INF
	for orb_id in range(get_orb_count()):
		var distance := absf(platform_x - get_world_x(orb_id))
		if distance > half_width or distance >= nearest_distance:
			continue
		nearest_id = orb_id
		nearest_distance = distance
	return nearest_id
