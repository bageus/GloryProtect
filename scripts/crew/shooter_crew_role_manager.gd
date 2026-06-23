class_name ShooterCrewRoleManager
extends CrewRoleManager


func _ready() -> void:
	super._ready()
	if not _crew.shooter_upgrades_changed.is_connected(
		_on_shooter_upgrades_changed
	):
		_crew.shooter_upgrades_changed.connect(
			_on_shooter_upgrades_changed
		)


func _is_role_available_in_prototype(
	role_id: int,
	station_id: int
) -> bool:
	if role_id == CrewRole.Id.SHOOTER:
		return _crew != null and _crew.is_shooter_role_unlocked()
	return super._is_role_available_in_prototype(role_id, station_id)


func _on_shooter_upgrades_changed() -> void:
	if _crew == null or _crew.is_shooter_role_unlocked():
		return
	_disable_dynamic_station(CrewRole.Id.SHOOTER, -1)
