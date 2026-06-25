class_name BoardingRewardController
extends Node

signal reward_granted(enemy_id: int, amount: int, reason: StringName)
signal strategic_reward_granted(section_id: int, amount: int)

@export_node_path("BoardingEnemyRegistry") var enemy_registry_path: NodePath
@export_node_path("RunEconomy") var run_economy_path: NodePath
@export_node_path("StrategicWaveSystem") var strategic_wave_path: NodePath
@export var balance: EconomyBalance

@onready var _enemies: BoardingEnemyRegistry = get_node(enemy_registry_path)
@onready var _economy: RunEconomy = get_node(run_economy_path)
var _strategic: StrategicWaveSystem


func _ready() -> void:
	assert(balance != null, "BoardingRewardController requires EconomyBalance")
	_enemies.enemy_removed.connect(_on_enemy_removed)
	_strategic = _resolve_strategic_wave_system()
	if _strategic != null:
		_strategic.strategic_enemy_impacted.connect(
			_on_strategic_enemy_impacted
		)


func _on_enemy_removed(enemy_id: int, reason: StringName) -> void:
	if not balance.is_rewarded_boarding_reason(reason):
		return
	var amount: int = balance.boarding_enemy_base_reward
	if amount <= 0:
		return
	_economy.add_coins(amount, reason)
	reward_granted.emit(enemy_id, amount, reason)


func _on_strategic_enemy_impacted(
	section_id: int,
	_damage: float
) -> void:
	var amount: int = balance.strategic_enemy_impact_reward
	if amount <= 0:
		return
	_economy.add_coins(amount, &"strategic_shield_impact")
	strategic_reward_granted.emit(section_id, amount)
	reward_granted.emit(-1, amount, &"strategic_shield_impact")


func _resolve_strategic_wave_system() -> StrategicWaveSystem:
	if not strategic_wave_path.is_empty():
		return get_node_or_null(strategic_wave_path) as StrategicWaveSystem
	return get_node_or_null("../StrategicWaveSystem") as StrategicWaveSystem
