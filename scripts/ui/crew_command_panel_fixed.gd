class_name CrewCommandPanelFixed
extends CrewCommandPanel

var _medical_system: MedicalStationSystem


func _ready() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root != null:
		_medical_system = scene_root.get_node_or_null(
			"World/MedicalStationSystem"
		) as MedicalStationSystem
	super._ready()


func _on_assign_pressed(slot_index: int, defender_id: int) -> void:
	if slot_index < 0 or slot_index >= _slot_specs.size():
		_set_feedback("Некорректный пост", true)
		return

	var spec: Dictionary = _slot_specs[slot_index]
	var kind: int = int(spec["kind"])
	if kind != SlotKind.MEDIC:
		super._on_assign_pressed(slot_index, defender_id)
		return

	if not are_commands_enabled():
		_set_feedback("Команды сейчас недоступны", true)
		return
	if _medical_system == null or not is_instance_valid(_medical_system):
		_set_feedback("Система медицинского поста не найдена", true)
		return

	_medical_system.call("_sync_station")
	var station_id: int = CrewRoleManager.DEFAULT_DYNAMIC_STATION_ID
	if not _roles.is_role_station_available(CrewRole.Id.MEDIC, station_id):
		_set_feedback("Медицинский пост ещё не зарегистрирован", true)
		return

	var assignment: CrewAssignmentRuntime = _roles.get_assignment(defender_id)
	if assignment == null:
		_set_feedback("Защитник недоступен", true)
		return
	if assignment.state != CrewAssignmentRuntime.State.ACTIVE:
		_set_feedback("Защитник занят текущим действием", true)
		return

	var previous_owner: int = int(_describe_slot(spec)["owner"])
	if previous_owner >= 0 and previous_owner != defender_id:
		_release_post_owner(previous_owner)

	_selection.select_defender(defender_id)
	_forget_free_cell(defender_id)
	_roles.request_assignment(
		defender_id,
		CrewRole.Id.MEDIC,
		station_id
	)

	assignment = _roles.get_assignment(defender_id)
	var accepted: bool = (
		assignment != null
		and (
			(
				assignment.current_role == CrewRole.Id.MEDIC
				and assignment.current_station_id == station_id
			)
			or (
				assignment.target_role == CrewRole.Id.MEDIC
				and assignment.target_station_id == station_id
			)
		)
	)
	if not accepted:
		_set_feedback("Назначение лекаря отклонено", true)
		return

	_set_feedback(
		"Защитник %d направлен на медицинский пост" % (defender_id + 1),
		false
	)
	_close_context()
