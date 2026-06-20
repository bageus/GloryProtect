class_name BuildableInventory
extends Node

signal buildable_unlocked(type_id: int, unlocked_count: int)
signal inventory_reset

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export var balance: BuildableBalance

var _unlocked_counts: Dictionary[int, int] = {}

@onready var _game_flow: GameFlowController = get_node(game_flow_path)


func _ready() -> void:
	assert(balance != null, "BuildableInventory requires BuildableBalance")
	_game_flow.run_state_changed.connect(_on_run_state_changed)
	reset_for_run()


func unlock(type_id: int, amount: int = 1) -> int:
	if amount <= 0:
		return get_unlocked_count(type_id)
	var maximum: int = balance.get_max_count(type_id)
	if maximum <= 0:
		return get_unlocked_count(type_id)
	var next_count: int = mini(
		maximum,
		get_unlocked_count(type_id) + amount
	)
	if next_count == get_unlocked_count(type_id):
		return next_count
	_unlocked_counts[type_id] = next_count
	buildable_unlocked.emit(type_id, next_count)
	return next_count


func get_unlocked_count(type_id: int) -> int:
	return int(_unlocked_counts.get(type_id, 0))


func is_unlocked(type_id: int) -> bool:
	return get_unlocked_count(type_id) > 0


func can_deploy(type_id: int, deployed_count: int) -> bool:
	return deployed_count < get_unlocked_count(type_id)


func reset_for_run() -> void:
	_unlocked_counts.clear()
	inventory_reset.emit()


func get_summary() -> String:
	return "медпост %d/%d" % [
		get_unlocked_count(BuildableType.Id.MEDICAL_STATION),
		balance.medical_station_max_count,
	]


func _on_run_state_changed(previous_state: int, new_state: int) -> void:
	if new_state != GameFlowController.RunState.START_DELAY:
		return
	if previous_state == GameFlowController.RunState.MANUAL_PAUSE:
		return
	reset_for_run()
