class_name BuildableType
extends RefCounted

enum Id {
	MEDICAL_STATION,
	TURRET,
}


static func get_display_name(type_id: int) -> String:
	match type_id:
		Id.MEDICAL_STATION:
			return "MEDICAL_STATION"
		Id.TURRET:
			return "TURRET"
		_:
			return "UNKNOWN"
