class_name BuildablePlacementControllerScene
extends BuildablePlacementController


func are_commands_enabled() -> bool:
	var flow := get_node_or_null(game_flow_path) as GameFlowController
	return flow != null and flow.state == GameFlowController.RunState.RUNNING


func begin_move_selected() -> bool:
	if not _ensure_commands_enabled():
		return false
	var snapshot: BuildableSnapshot = _grid.get_snapshot(selected_buildable_id)
	if snapshot == null:
		_set_feedback("Сначала выберите установленный объект", true)
		return false
	selected_type_id = snapshot.type_id
	_set_mode(Mode.MOVE)
	_set_feedback("Выберите новую зелёную клетку", false)
	return true
