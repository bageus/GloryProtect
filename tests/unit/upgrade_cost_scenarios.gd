extends SceneTree


func _init() -> void:
	var balance := UpgradeBalance.new()
	balance.linear_offer_count = 20
	balance.linear_step_cost = 5
	balance.post_linear_multiplier = 2

	assert(balance.get_cost_for_completed_count(0) == 5)
	assert(balance.get_cost_for_completed_count(1) == 10)
	assert(balance.get_cost_for_completed_count(18) == 95)
	assert(balance.get_cost_for_completed_count(19) == 100)
	assert(balance.get_cost_for_completed_count(20) == 200)
	assert(balance.get_cost_for_completed_count(21) == 400)
	assert(balance.get_cost_for_completed_count(22) == 800)
	assert(balance.get_cost_for_completed_count(-1) == 5)

	print("Upgrade cost scenarios passed")
	quit()
