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
	var cards: HBoxContainer = panel.get_node(
		"Center/Panel/Margin/VBox/CardsContainer"
	)
	var diagnostics_toggle: CheckButton = panel.get_node(
		"Center/Panel/Margin/VBox/DiagnosticsToggle"
	)
	var diagnostics_label: RichTextLabel = panel.get_node(
		"Center/Panel/Margin/VBox/DiagnosticsLabel"
	)

	game_flow.state = GameFlowController.RunState.RUNNING
	economy.add_coins(15, &"test_upgrade_ui")
	assert(upgrades.is_offer_open())
	assert(paused)
	assert(panel.visible)
	assert(upgrades.get_card_count() == 3)
	assert(cards.get_child_count() == 3)

	for child: Node in cards.get_children():
		assert(child is Button)
		var button: Button = child as Button
		assert(button.text.contains("Эффект:"))
		assert(button.text.contains("Требования:"))

	diagnostics_toggle.button_pressed = true
	panel.call("_on_diagnostics_toggled", true)
	assert(diagnostics_label.visible)
	assert(not diagnostics_label.text.is_empty())
	assert(diagnostics_label.text.contains("common_"))

	var first_offer_number: int = upgrades.get_current_offer_number()
	var selected_id: StringName = upgrades.get_card_id(0)
	assert(bool(panel.call(
		"_submit_card",
		selected_id,
		first_offer_number
	)))
	assert(upgrades.get_current_offer_number() == first_offer_number + 1)
	assert(upgrades.is_offer_open())
	assert(paused)
	assert(not bool(panel.call(
		"_submit_card",
		selected_id,
		first_offer_number
	)))
	assert(upgrades.get_completed_purchase_count() == 1)

	var second_offer_number: int = upgrades.get_current_offer_number()
	var second_id: StringName = upgrades.get_card_id(0)
	assert(bool(panel.call(
		"_submit_card",
		second_id,
		second_offer_number
	)))
	assert(not upgrades.is_offer_open())
	assert(not paused)
	assert(not panel.visible)

	print("Upgrade UI scenarios passed")
	quit()
