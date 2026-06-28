class_name RunStatisticsSnapshot
extends RefCounted

var survival_seconds: float
var physical_kills: int
var remaining_coins: int
var purchased_upgrades: int
var end_reason: StringName
var earned_coins: int
var spent_coins: int
var coins_per_minute: float
var purchase_timeline: Array
var offer_slot_counts: Dictionary
var specialization_purchase_numbers: Array[int]


func _init(
	new_survival_seconds: float,
	new_physical_kills: int,
	new_remaining_coins: int,
	new_purchased_upgrades: int,
	new_end_reason: StringName,
	new_earned_coins: int = 0,
	new_spent_coins: int = 0,
	new_purchase_timeline: Array = [],
	new_offer_slot_counts: Dictionary = {},
	new_specialization_purchase_numbers: Array[int] = []
) -> void:
	survival_seconds = maxf(0.0, new_survival_seconds)
	physical_kills = maxi(0, new_physical_kills)
	remaining_coins = maxi(0, new_remaining_coins)
	purchased_upgrades = maxi(0, new_purchased_upgrades)
	end_reason = new_end_reason
	earned_coins = maxi(0, new_earned_coins)
	spent_coins = maxi(0, new_spent_coins)
	coins_per_minute = (
		float(earned_coins) * 60.0 / survival_seconds
		if survival_seconds > 0.0
		else 0.0
	)
	purchase_timeline = new_purchase_timeline.duplicate(true)
	offer_slot_counts = new_offer_slot_counts.duplicate(true)
	specialization_purchase_numbers = new_specialization_purchase_numbers.duplicate()
