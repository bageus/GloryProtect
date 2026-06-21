extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


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
	var panel: UpgradeSelectionPanel = game.get_node(
		"CanvasLayer/UpgradeSelectionPanel"
	)
	var specialization_label: Label = panel.get_node(
		"Center/Panel/Margin/VBox/SpecializationLabel"
	)
	var cards: HBoxContainer = panel.get_node(
		"Center/Panel/Margin/VBox/CardsContainer"
	)
	var runtime: UpgradeRuntime = upgrades.get_runtime()
	var basic: UpgradeDefinition = upgrades.catalog.get_definition(
		&"turret_basic_damage"
	)
	var advanced: UpgradeDefinition = upgrades.catalog.get_definition(
		&"turret_advanced_rate"
	)

	assert(runtime.record_card(basic))
	assert(runtime.record_card(advanced))
	assert(runtime.is_branch_ready_for_specialization(&"turret"))

	game_flow.state = GameFlowController.RunState.RUNNING
	economy.add_coins(5, &"test_specialization_ui")
	assert(upgrades.is_offer_open())
	assert(upgrades.is_specialization_offer())
	assert(upgrades.get_specialization_offer_branch() == &"turret")
	assert(paused)
	assert(panel.visible)
	assert(specialization_label.visible)
	assert(specialization_label.text.contains("Турели"))
	assert(cards.get_child_count() == 3)

	for child: Node in cards.get_children():
		assert(child is Button)
		var button: Button = child as Button
		assert(button.text.contains("Специализация"))
		assert(button.text.contains("ВНИМАНИЕ:"))
		assert(button.text.contains("заблокирует"))

	var selected_id: StringName = upgrades.get_card_id(0)
	var offer_number: int = upgrades.get_current_offer_number()
	assert(bool(panel.call("_submit_card", selected_id, offer_number)))
	assert(runtime.get_specialization(&"turret") == selected_id)
	assert(not upgrades.is_offer_open())
	assert(not paused)

	var closed_count: int = 0
	for specialization_id: StringName in [
		&"turret_specialization_heavy",
		&"turret_specialization_rapid",
		&"turret_specialization_electric",
	]:
		if specialization_id == selected_id:
			continue
		assert(runtime.is_specialization_closed(specialization_id))
		closed_count += 1
	assert(closed_count == 2)

	print("Upgrade specialization UI scenarios passed")
	quit()
