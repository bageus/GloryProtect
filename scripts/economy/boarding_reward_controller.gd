class_name BoardingRewardController
extends Node

signal reward_granted(enemy_id: int, amount: int, reason: StringName)

@export_node_path("BoardingEnemyRegistry") var enemy_registry_path: NodePath
@export_node_path("RunEconomy") var run_economy_path: NodePath
@export var balance: EconomyBalance

@onready var _enemies: BoardingEnemyRegistry = get_node(enemy_registry_path)
@onready var _economy: RunEconomy = get_node(run_economy_path)


func _ready() -> void:
	assert(balance != null, "BoardingRewardController requires EconomyBalance")
	_enemies.enemy_removed.connect(_on_enemy_removed)


func _on_enemy_removed(enemy_id: int, reason: StringName) -> void:
	if not balance.is_rewarded_boarding_reason(reason):
		return
	var amount: int = balance.boarding_enemy_base_reward
	if amount <= 0:
		return
	_economy.add_coins(amount, reason)
	reward_granted.emit(enemy_id, amount, reason)
