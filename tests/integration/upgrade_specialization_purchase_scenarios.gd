extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run_scenario")


func _run_scenario() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var flow: GameFlowController = game.get_node("GameFlowController")
	var economy: RunEconomy = game.get_node("RunEconomy")
	var upgrades: UpgradeSystem = game.get_node("UpgradeSystem")
	var runtime: UpgradeRuntime = upgrades.get_runtime()
	flow.state = GameFlowController.RunState.RUNNING

	assert(runtime.record_card(upgrades.catalog.get_definition(
		&"turret_post"
	)))
	assert(runtime.record_card(upgrades.catalog.get_definition(
		&"turret_damage_basic"
	)))
	assert(runtime.record_card(upgrades.catalog.get_definition(
		&"turret_damage_advanced"
	)))
	assert(runtime.is_branch_ready_for_specialization(&"turret"))

	economy.add_coins(30, &"specialization_test")
	await process_frame
	await process_frame

	assert(upgrades.is_offer_open())
	assert(upgrades.is_specialization_offer())
	assert(upgrades.get_specialization_offer_branch() == &"turret")
	assert(upgrades.get_card_count() == 3)
	var starting_coins: int = economy.get_coins()
	var cost: int = upgrades.get_current_cost()
	var specialization_id: StringName = upgrades.get_card_id(0)
	assert(upgrades.choose_card_by_id(specialization_id))
	assert(economy.get_coins() == starting_coins - cost)
	assert(runtime.get_specialization(&"turret") == specialization_id)
	assert(not runtime.is_branch_ready_for_specialization(&"turret"))
	assert(upgrades.get_completed_purchase_count() == 1)
	assert(upgrades.is_offer_open())
	assert(not upgrades.is_specialization_offer())

	print("Upgrade specialization purchase scenario passed")
	quit()
