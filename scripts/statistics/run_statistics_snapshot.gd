class_name RunStatisticsSnapshot
extends RefCounted

var survival_seconds: float
var physical_kills: int
var remaining_coins: int
var purchased_upgrades: int
var end_reason: StringName


func _init(
	new_survival_seconds: float,
	new_physical_kills: int,
	new_remaining_coins: int,
	new_purchased_upgrades: int,
	new_end_reason: StringName
) -> void:
	survival_seconds = maxf(0.0, new_survival_seconds)
	physical_kills = maxi(0, new_physical_kills)
	remaining_coins = maxi(0, new_remaining_coins)
	purchased_upgrades = maxi(0, new_purchased_upgrades)
	end_reason = new_end_reason
