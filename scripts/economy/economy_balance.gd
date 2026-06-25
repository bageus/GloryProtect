class_name EconomyBalance
extends Resource

@export_range(0, 1000, 1) var starting_coins: int = 0
@export_range(0, 1000, 1) var boarding_enemy_base_reward: int = 1
@export_range(0, 1000, 1) var strategic_enemy_impact_reward: int = 1
@export var rewarded_boarding_death_reasons: Array[StringName] = [
	&"combat",
	&"anchor_path_closed",
	&"shooter_anchor_knockdown",
]


func is_rewarded_boarding_reason(reason: StringName) -> bool:
	return rewarded_boarding_death_reasons.has(reason)
