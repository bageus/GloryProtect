extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var game_flow: GameFlowController = game.get_node("GameFlowController")
	var economy: RunEconomy = game.get_node("RunEconomy")
	var upgrades: UpgradeSystem = game.get_node("UpgradeSystem")

	game_flow.state = GameFlowController.RunState.RUNNING
	assert(not get_tree().paused)
	assert(upgrades.get_completed_purchase_count() == 0)
	assert(upgrades.get_current_cost() == 5)
	assert(upgrades.get_card_count() == 2)
	assert(upgrades.get_card_title(0) == upgrades.get_card_title(1))
	assert(
		upgrades.get_card_description(0)
		== upgrades.get_card_description(1)
	)

	economy.add_coins(35, &"test_upgrade_funding")
	assert(upgrades.is_offer_open())
	assert(game_flow.state == GameFlowController.RunState.CARD_SELECTION)
	assert(get_tree().paused)
	assert(upgrades.get_current_offer_number() == 1)
	assert(upgrades.get_current_cost() == 5)
	assert(not upgrades.choose_card(-1))
	assert(not upgrades.choose_card(2))
	assert(economy.get_coins() == 35)

	assert(upgrades.choose_card(0))
	assert(economy.get_coins() == 30)
	assert(upgrades.get_completed_purchase_count() == 1)
	assert(upgrades.get_current_offer_number() == 2)
	assert(upgrades.get_current_cost() == 10)
	assert(upgrades.is_offer_open())
	assert(get_tree().paused)

	assert(upgrades.choose_card(1))
	assert(economy.get_coins() == 20)
	assert(upgrades.get_completed_purchase_count() == 2)
	assert(upgrades.get_current_cost() == 15)
	assert(upgrades.is_offer_open())
	assert(get_tree().paused)

	assert(upgrades.choose_card(0))
	assert(economy.get_coins() == 5)
	assert(upgrades.get_completed_purchase_count() == 3)
	assert(upgrades.get_current_cost() == 20)
	assert(not upgrades.is_offer_open())
	assert(game_flow.state == GameFlowController.RunState.RUNNING)
	assert(not get_tree().paused)

	game_flow.end_run(&"test_restart")
	game_flow.start_run()
	await process_frame
	assert(economy.get_coins() == economy.balance.starting_coins)
	assert(upgrades.get_completed_purchase_count() == 0)
	assert(upgrades.get_current_cost() == 5)
	assert(not upgrades.is_offer_open())

	print("Upgrade selection scenarios passed")
	quit()
