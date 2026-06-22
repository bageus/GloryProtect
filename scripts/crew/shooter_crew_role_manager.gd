class_name ShooterCrewRoleManager
extends CrewRoleManager


func _is_role_available_in_prototype(
	role_id: int,
	station_id: int
) -> bool:
	if role_id == CrewRole.Id.SHOOTER:
		return _crew != null and _crew.is_shooter_role_unlocked()
	return super._is_role_available_in_prototype(role_id, station_id)
