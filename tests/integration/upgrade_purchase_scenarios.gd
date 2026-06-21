extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var flow: GameFlowController = game.get_node("GameFlowController")
	var economy: RunEconomy = game.get_node("RunEconomy")
	var upgrades: UpgradeSystem = game.get_node("UpgradeSystem")
	flow.state = GameFlowController.RunState.RUNNING
	economy.add_coins(30, &"upgrade_test")
	await process_frame
	await process_frame

	assert(upgrades.is_offer_open())
	assert(upgrades.get_card_count() > 0)
	var starting_coins: int = economy.get_coins()
	var starting_cost: int = upgrades.get_current_cost()
	assert(not upgrades.choose_card_by_id(&"unknown_card"))
	assert(economy.get_coins() == starting_coins)
	assert(upgrades.get_completed_purchase_count() == 0)

	var selected_id: StringName = upgrades.get_card_id(0)
	assert(selected_id != &"")
	assert(upgrades.choose_card_by_id(selected_id))
	assert(economy.get_coins() == starting_coins - starting_cost)
	assert(upgrades.get_completed_purchase_count() == 1)
	assert(upgrades.get_runtime().has_card(selected_id))

	upgrades.reset_for_run()
	assert(upgrades.get_completed_purchase_count() == 0)
	assert(upgrades.get_runtime().get_selected_cards().is_empty())

	print("Upgrade purchase scenarios passed")
	quit()
