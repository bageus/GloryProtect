class_name BuildablePlacementControllerScene
extends BuildablePlacementController


func are_commands_enabled() -> bool:
	var flow := get_node_or_null(game_flow_path) as GameFlowController
	return flow != null and flow.state == GameFlowController.RunState.RUNNING
