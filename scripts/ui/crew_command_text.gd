class_name CrewCommandText
extends RefCounted


static func role_title(role_id: int) -> String:
	match role_id:
		CrewRole.Id.FREE_FIGHTER:
			return "Свободный боец"
		CrewRole.Id.DRIVER:
			return "Рулевой"
		CrewRole.Id.LEFT_ANCHOR:
			return "Левый якорщик"
		CrewRole.Id.RIGHT_ANCHOR:
			return "Правый якорщик"
		CrewRole.Id.MEDIC:
			return "Лекарь"
		CrewRole.Id.TURRET:
			return "Турельщик"
		_:
			return "Неизвестная роль"


static func owner_text(owner_id: int, selected_id: int) -> String:
	if owner_id < 0:
		return "свободно"
	if owner_id == selected_id:
		return "занято выбранным"
	return "занято защитником %d" % (owner_id + 1)


static func assignment_short(assignment: CrewAssignmentRuntime) -> String:
	if assignment == null:
		return "ИНИЦИАЛИЗАЦИЯ"
	var result: String = role_title(assignment.current_role)
	if assignment.state != CrewAssignmentRuntime.State.ACTIVE:
		result += " → %s" % role_title(assignment.target_role)
	return result


static func assignment_long(assignment: CrewAssignmentRuntime) -> String:
	if assignment == null:
		return "не инициализирован"
	var current: String = role_station_title(
		assignment.current_role,
		assignment.current_station_id
	)
	match assignment.state:
		CrewAssignmentRuntime.State.ACTIVE:
			return "роль: %s" % current
		CrewAssignmentRuntime.State.MOVING:
			return "движется: %s → %s" % [
				current,
				role_station_title(
					assignment.target_role,
					assignment.target_station_id
				),
			]
		CrewAssignmentRuntime.State.WAITING_FOR_ACTION:
			return "завершает действие, затем → %s" % role_station_title(
				assignment.target_role,
				assignment.target_station_id
			)
		CrewAssignmentRuntime.State.DEAD:
			return "погиб"
		_:
			return current


static func role_station_title(role_id: int, station_id: int) -> String:
	var result: String = role_title(role_id)
	if role_id == CrewRole.Id.TURRET and station_id >= 0:
		result += " T%d" % (station_id + 1)
	return result


static func rejection_text(reason: StringName) -> String:
	match reason:
		&"unknown_defender":
			return "Защитник не найден"
		&"role_unavailable":
			return "Рабочий пост ещё не установлен"
		&"defender_dead":
			return "Погибшему защитнику нельзя назначить роль"
		&"defender_busy":
			return "Защитник уже выполняет переход или ожидает завершения действия"
		&"station_occupied":
			return "Этот рабочий пост уже занят"
		_:
			return "Команда отклонена: %s" % String(reason)
