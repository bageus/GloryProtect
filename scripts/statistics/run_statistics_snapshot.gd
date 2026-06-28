class_name RunStatisticsSnapshot
extends RefCounted

const GENERAL_POOL_ID: StringName = &"general"

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


func get_offer_slot_total() -> int:
	var total: int = 0
	for raw_count: Variant in offer_slot_counts.values():
		total += maxi(0, int(raw_count))
	return total


func get_offer_share(pool_id: StringName) -> float:
	var total: int = get_offer_slot_total()
	if total <= 0:
		return 0.0
	return float(offer_slot_counts.get(pool_id, 0)) / float(total)


func get_purchase_time_seconds(purchase_number: int) -> float:
	if purchase_number <= 0:
		return -1.0
	for raw_entry: Variant in purchase_timeline:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		if int(entry.get("purchase_number", 0)) != purchase_number:
			continue
		return maxf(0.0, float(entry.get("time_seconds", 0.0)))
	return -1.0


func get_specialization_purchase_number(index: int) -> int:
	if index < 0 or index >= specialization_purchase_numbers.size():
		return -1
	return specialization_purchase_numbers[index]


func get_balance_summary_text() -> String:
	var twentieth_time: float = get_purchase_time_seconds(20)
	var twentieth_text: String = (
		"%.2f min" % (twentieth_time / 60.0)
		if twentieth_time >= 0.0
		else "not reached"
	)
	var specialization_parts := PackedStringArray()
	for purchase_number: int in specialization_purchase_numbers:
		specialization_parts.append(str(purchase_number))
	var specializations_text: String = (
		", ".join(specialization_parts)
		if not specialization_parts.is_empty()
		else "none"
	)
	return (
		"NEXT-17 RUN | survival %.2f min | kills %d | coins %d earned / %d spent / %d left "
		+ "| coins/min %.2f | purchases %d | purchase #20 %s | specializations %s "
		+ "| general pool %.2f%% | end %s"
	) % [
		survival_seconds / 60.0,
		physical_kills,
		earned_coins,
		spent_coins,
		remaining_coins,
		coins_per_minute,
		purchased_upgrades,
		twentieth_text,
		specializations_text,
		get_offer_share(GENERAL_POOL_ID) * 100.0,
		String(end_reason),
	]
