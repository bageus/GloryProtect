extends SceneTree

const ECONOMY_BALANCE: EconomyBalance = preload(
	"res://resources/balance/economy_balance.tres"
)


func _init() -> void:
	call_deferred("_run_scenario")


func _run_scenario() -> void:
	assert(ECONOMY_BALANCE.is_rewarded_boarding_reason(
		&"shooter_anchor_knockdown"
	))

	var flow := GameFlowController.new()
	flow.name = "GameFlowController"
	flow.start_delay_seconds = 0.0
	root.add_child(flow)

	var registry := BoardingEnemyRegistry.new()
	registry.name = "BoardingEnemyRegistry"
	root.add_child(registry)

	var economy := RunEconomy.new()
	economy.name = "RunEconomy"
	economy.game_flow_path = NodePath("../GameFlowController")
	economy.balance = ECONOMY_BALANCE
	root.add_child(economy)

	var rewards := BoardingRewardController.new()
	rewards.name = "BoardingRewardController"
	rewards.enemy_registry_path = NodePath("../BoardingEnemyRegistry")
	rewards.run_economy_path = NodePath("../RunEconomy")
	rewards.balance = ECONOMY_BALANCE
	root.add_child(rewards)

	assert(economy.get_coins() == ECONOMY_BALANCE.starting_coins)
	registry.enemy_removed.emit(1, &"shooter_anchor_knockdown")
	assert(
		economy.get_coins()
		== ECONOMY_BALANCE.starting_coins
		+ ECONOMY_BALANCE.boarding_enemy_base_reward
	)
	print("Shooter reward reason scenario passed")
	quit()
