class_name UpgradeBalance
extends Resource

const MAX_COST: int = 2147483647

@export_range(2, 8, 1) var cards_per_offer: int = 2
@export_range(1, 100, 1) var linear_offer_count: int = 20
@export_range(1, 10000, 1) var linear_step_cost: int = 5
@export_range(2, 10, 1) var post_linear_multiplier: int = 2
@export var placeholder_title: String = "Тестовая карточка"
@export_multiline var placeholder_description: String = (
	"Эффект карточки пока не реализован."
)


func get_cost_for_completed_count(completed_count: int) -> int:
	var safe_completed_count: int = maxi(0, completed_count)
	if safe_completed_count < linear_offer_count:
		return (safe_completed_count + 1) * linear_step_cost

	var cost: int = linear_offer_count * linear_step_cost
	var multiplier_steps: int = (
		safe_completed_count - linear_offer_count + 1
	)
	for _step: int in range(multiplier_steps):
		if cost > MAX_COST / post_linear_multiplier:
			return MAX_COST
		cost *= post_linear_multiplier
	return cost
