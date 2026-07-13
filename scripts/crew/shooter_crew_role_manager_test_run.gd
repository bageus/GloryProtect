class_name ShooterCrewRoleManagerTestRun
extends ShooterCrewRoleManagerPolished


func _ready() -> void:
	super._ready()
	if not _crew.defender_removed.is_connected(_on_test_run_defender_removed):
		_crew.defender_removed.connect(_on_test_run_defender_removed)


func _on_test_run_defender_removed(defender_id: int) -> void:
	var runtime: CrewAssignmentRuntime = get_assignment(defender_id)
	if runtime == null:
		return
	_deactivate_capability(runtime.current_role)
	_stations.release(
		runtime.current_role,
		runtime.current_station_id,
		defender_id
	)
	_stations.release(
		runtime.target_role,
		runtime.target_station_id,
		defender_id
	)
	_external_action_roles.erase(defender_id)
	_assignments.erase(defender_id)
