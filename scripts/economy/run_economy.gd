class_name RunEconomy
extends Node

signal coins_changed(
	previous_amount: int,
	current_amount: int,
	delta: int,
	source: StringName
)
signal coins_added(amount: int, source: StringName)
signal coins_spent(amount: int, source: StringName)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export var balance: EconomyBalance

var _coins: int = 0

@onready var _game_flow: GameFlowController = get_node(game_flow_path)


func _ready() -> void:
	assert(balance != null, "RunEconomy requires EconomyBalance")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game_flow.run_state_changed.connect(_on_run_state_changed)
	reset_for_run()


func get_coins() -> int:
	return _coins


func can_afford(cost: int) -> bool:
	return cost >= 0 and _coins >= cost


func add_coins(amount: int, source: StringName = &"") -> void:
	if amount <= 0:
		return
	var previous_amount: int = _coins
	_coins += amount
	coins_added.emit(amount, source)
	coins_changed.emit(previous_amount, _coins, amount, source)


func spend_coins(cost: int, source: StringName = &"") -> bool:
	if cost < 0 or not can_afford(cost):
		return false
	if cost == 0:
		return true
	var previous_amount: int = _coins
	_coins -= cost
	coins_spent.emit(cost, source)
	coins_changed.emit(previous_amount, _coins, -cost, source)
	return true


func reset_for_run() -> void:
	var previous_amount: int = _coins
	_coins = maxi(0, balance.starting_coins)
	if previous_amount == _coins:
		return
	coins_changed.emit(
		previous_amount,
		_coins,
		_coins - previous_amount,
		&"run_reset"
	)


func _on_run_state_changed(previous_state: int, new_state: int) -> void:
	if new_state != GameFlowController.RunState.START_DELAY:
		return
	if (
		previous_state == GameFlowController.RunState.BOOT
		or previous_state == GameFlowController.RunState.GAME_OVER
	):
		reset_for_run()
