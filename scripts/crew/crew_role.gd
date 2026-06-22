class_name CrewRole
extends RefCounted

enum Id {
	FREE_FIGHTER,
	DRIVER,
	LEFT_ANCHOR,
	RIGHT_ANCHOR,
	MEDIC,
	TURRET,
	SHOOTER,
}


static func get_display_name(role_id: int) -> String:
	match role_id:
		Id.FREE_FIGHTER:
			return "FREE"
		Id.DRIVER:
			return "DRIVER"
		Id.LEFT_ANCHOR:
			return "LEFT_ANCHOR"
		Id.RIGHT_ANCHOR:
			return "RIGHT_ANCHOR"
		Id.MEDIC:
			return "MEDIC"
		Id.TURRET:
			return "TURRET"
		Id.SHOOTER:
			return "SHOOTER"
		_:
			return "UNKNOWN"


static func is_fixed_station(role_id: int) -> bool:
	return (
		role_id == Id.DRIVER
		or role_id == Id.LEFT_ANCHOR
		or role_id == Id.RIGHT_ANCHOR
		or role_id == Id.MEDIC
		or role_id == Id.TURRET
	)
