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
	var platform: PlatformController = game.get_node("World/Platform")

	game_flow.state = GameFlowController.RunState.RUNNING
	assert(not paused)
	assert(upgrades.get_completed_purchase_count() == 0)
	assert(upgrades.get_current_cost() == 5)
	assert(upgrades.get_card_count() == 3)

	platform.horizontal_velocity = 100.0
	economy.add_coins(35, &"test_upgrade_funding")
	assert(upgrades.is_offer_open())
	assert(game_flow.state == GameFlowController.RunState.CARD_SELECTION)
	assert(paused)
	assert(upgrades.get_current_offer_number() == 1)
	assert(upgrades.get_current_cost() == 5)
	_assert_current_offer_is_unique(upgrades)

	var paused_platform_x: float = platform.position.x
	await _wait_physics_frames(5)
	assert(is_equal_approx(platform.position.x, paused_platform_x))

	assert(not upgrades.choose_card(-1))
	assert(not upgrades.choose_card(upgrades.get_card_count()))
	assert(economy.get_coins() == 35)

	assert(upgrades.choose_card(0))
	assert(economy.get_coins() == 30)
	assert(upgrades.get_completed_purchase_count() == 1)
	assert(upgrades.get_current_offer_number() == 2)
	assert(upgrades.get_current_cost() == 10)
	assert(upgrades.is_offer_open())
	assert(paused)
	_assert_current_offer_is_unique(upgrades)

	assert(upgrades.choose_card(0))
	assert(economy.get_coins() == 20)
	assert(upgrades.get_completed_purchase_count() == 2)
	assert(upgrades.get_current_cost() == 15)
	assert(upgrades.is_offer_open())
	assert(paused)
	_assert_current_offer_is_unique(upgrades)

	assert(upgrades.choose_card(0))
	assert(economy.get_coins() == 5)
	assert(upgrades.get_completed_purchase_count() == 3)
	assert(upgrades.get_current_cost() == 20)
	assert(not upgrades.is_offer_open())
	assert(game_flow.state == GameFlowController.RunState.RUNNING)
	assert(not paused)

	game_flow.end_run(&"test_restart")
	game_flow.start_run()
	await process_frame
	assert(economy.get_coins() == economy.balance.starting_coins)
	assert(upgrades.get_completed_purchase_count() == 0)
	assert(upgrades.get_current_cost() == 5)
	assert(not upgrades.is_offer_open())

	print("Upgrade selection scenarios passed")
	quit()


func _assert_current_offer_is_unique(upgrades: UpgradeSystem) -> void:
	var card_count: int = upgrades.get_card_count()
	assert(card_count > 0 and card_count <= 3)
	var seen: Dictionary[StringName, bool] = {}
	for card_index: int in range(card_count):
		var card_id: StringName = upgrades.get_card_id(card_index)
		assert(card_id != &"")
		assert(not seen.has(card_id))
		seen[card_id] = true


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await physics_frame
