class_name ShieldCoreGroundOrbRegistry
extends GroundOrbRegistry

var _contact_width_multiplier: float = 1.0


func set_contact_width_multiplier(value: float) -> void:
	_contact_width_multiplier = maxf(1.0, value)


func reset_contact_width_multiplier() -> void:
	_contact_width_multiplier = 1.0


func get_contact_width_multiplier() -> float:
	return _contact_width_multiplier


func get_contact_half_width() -> float:
	return catalog.contact_half_width * _contact_width_multiplier


func get_contact_orb_at(platform_x: float) -> int:
	return _find_orb_in_range(platform_x, get_contact_half_width())


func is_platform_in_contact(orb_id: int, platform_x: float) -> bool:
	if not is_valid_orb(orb_id):
		return false
	return absf(platform_x - get_world_x(orb_id)) <= get_contact_half_width()
