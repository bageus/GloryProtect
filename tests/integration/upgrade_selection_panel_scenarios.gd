extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	_test_all_card_type_presentation_mapping()
	await _test_three_cards_and_stale_command_rejection()
	await _test_offer_with_fewer_than_three_cards()
	await _test_specialization_offer()
	print("Upgrade selection panel scenarios passed")
	quit()


func _test_all_card_type_presentation_mapping() -> void:
	assert(
		UpgradeCardFormatter.get_card_group_id(UpgradeDefinition.CardType.BASIC)
		== &"basic"
	)
	assert(
		UpgradeCardFormatter.get_card_group_id(UpgradeDefinition.CardType.ADVANCED)
		== &"basic"
	)
	assert(
		UpgradeCardFormatter.get_card_group_id(UpgradeDefinition.CardType.UNLOCK)
		== &"main"
	)
	assert(
		UpgradeCardFormatter.get_card_group_id(UpgradeDefinition.CardType.GENERAL)
		== &"main"
	)
	assert(
		UpgradeCardFormatter.get_card_group_id(UpgradeDefinition.CardType.SPECIALIZATION)
		== &"specialization"
	)
	assert(
		UpgradeCardFormatter.get_card_group_id(UpgradeDefinition.CardType.INDIVIDUAL)
		== &"special"
	)
	assert(
		UpgradeCardFormatter.get_card_group_id(
			UpgradeDefinition.CardType.SPECIALIZATION_EXTRA
		) == &"special"
	)
	for card_type: int in [
		UpgradeDefinition.CardType.UNLOCK,
		UpgradeDefinition.CardType.BASIC,
		UpgradeDefinition.CardType.ADVANCED,
		UpgradeDefinition.CardType.INDIVIDUAL,
		UpgradeDefinition.CardType.SPECIALIZATION,
		UpgradeDefinition.CardType.SPECIALIZATION_EXTRA,
		UpgradeDefinition.CardType.GENERAL,
	]:
		assert(not UpgradeCardFormatter.get_card_group_name(card_type).is_empty())
		assert(not UpgradeCardFormatter.get_card_group_symbol(card_type).is_empty())
		var accent: Color = UpgradeCardFormatter.get_card_group_accent_color(
			card_type
		)
		assert(accent.a > 0.0)


func _test_three_cards_and_stale_command_rejection() -> void:
	var catalog := UpgradeCatalog.new()
	var scalar_card := _make_card(
		&"same_branch_a",
		UpgradeDefinition.CardType.BASIC,
		&"turret"
	)
	scalar_card.effect = _make_domain_scalar_effect()
	catalog.definitions.append(scalar_card)
	catalog.definitions.append(
		_make_card(&"same_branch_b", UpgradeDefinition.CardType.BASIC, &"turret")
	)
	catalog.definitions.append(
		_make_card(&"same_branch_c", UpgradeDefinition.CardType.BASIC, &"turret")
	)
	var game: Node2D = await _spawn_game(catalog)
	var economy: RunEconomy = game.get_node("RunEconomy")
	var upgrades: UpgradeSystem = game.get_node("UpgradeSystem")
	var panel: UpgradeSelectionPanel = game.get_node(
		"CanvasLayer/UpgradeSelectionPanel"
	)

	economy.add_coins(1000, &"ui_test")
	await process_frame
	assert(upgrades.is_offer_open())
	assert(panel.visible)
	assert(panel.get_rendered_card_count() == 3)
	assert(upgrades.get_card_count() == 3)
	assert(not panel.is_global_cost_visible())
	assert(paused)

	var cost: int = upgrades.get_current_cost()
	for card_index: int in range(panel.get_rendered_card_count()):
		var card_text: String = panel.get_rendered_card_text(card_index)
		assert(card_text.contains("Цена: %d" % cost))
		assert(panel.get_rendered_card_group_id(card_index) == &"basic")
		assert(card_text.contains("БАЗОВАЯ"))
		assert(card_text.contains("◆"))
		assert(not card_text.contains("Изменяет параметр:"))
	assert(panel.get_rendered_card_text(0).contains("Модификатор:"))

	var offer_number: int = upgrades.get_current_offer_number()
	var card_id: StringName = upgrades.get_card_id(0)
	var coins_before: int = economy.get_coins()
	assert(upgrades.choose_card_for_offer(card_id, offer_number))
	assert(not upgrades.choose_card_for_offer(card_id, offer_number))
	assert(economy.get_coins() == coins_before - cost)
	assert(upgrades.get_completed_purchase_count() == 1)
	assert(upgrades.is_offer_open())
	assert(paused)
	await _remove_game(game)


func _test_offer_with_fewer_than_three_cards() -> void:
	var catalog := UpgradeCatalog.new()
	catalog.definitions.append(
		_make_card(&"general_a", UpgradeDefinition.CardType.GENERAL, &"")
	)
	catalog.definitions.append(
		_make_card(&"general_b", UpgradeDefinition.CardType.GENERAL, &"")
	)
	var game: Node2D = await _spawn_game(catalog)
	var economy: RunEconomy = game.get_node("RunEconomy")
	var upgrades: UpgradeSystem = game.get_node("UpgradeSystem")
	var panel: UpgradeSelectionPanel = game.get_node(
		"CanvasLayer/UpgradeSelectionPanel"
	)

	economy.add_coins(10, &"ui_test")
	await process_frame
	assert(upgrades.is_offer_open())
	assert(upgrades.get_card_count() == 2)
	assert(panel.get_rendered_card_count() == 2)
	assert(upgrades.get_card_id(0) != upgrades.get_card_id(1))
	for card_index: int in range(panel.get_rendered_card_count()):
		assert(panel.get_rendered_card_group_id(card_index) == &"main")
		assert(panel.get_rendered_card_text(card_index).contains("ОСНОВНАЯ"))
	await _remove_game(game)


func _test_specialization_offer() -> void:
	var catalog := UpgradeCatalog.new()
	for index: int in range(5):
		catalog.definitions.append(_make_card(
			StringName("turret_progress_%d" % index),
			UpgradeDefinition.CardType.BASIC,
			&"turret"
		))
	var specialization_ids: Array[StringName] = [
		&"turret_spec_heavy",
		&"turret_spec_rapid",
		&"turret_spec_electric",
	]
	for card_id: StringName in specialization_ids:
		var definition := _make_card(
			card_id,
			UpgradeDefinition.CardType.SPECIALIZATION,
			&"turret"
		)
		for other_id: StringName in specialization_ids:
			if other_id != card_id:
				definition.closes_specialization_ids.append(other_id)
		catalog.definitions.append(definition)

	var game: Node2D = await _spawn_game(catalog)
	var economy: RunEconomy = game.get_node("RunEconomy")
	var upgrades: UpgradeSystem = game.get_node("UpgradeSystem")
	var panel: UpgradeSelectionPanel = game.get_node(
		"CanvasLayer/UpgradeSelectionPanel"
	)
	for index: int in range(5):
		assert(upgrades.get_runtime().record_card(
			catalog.get_definition(StringName("turret_progress_%d" % index))
		))

	economy.add_coins(10, &"ui_test")
	await process_frame
	assert(upgrades.is_specialization_offer())
	assert(upgrades.get_specialization_offer_branch() == &"turret")
	assert(panel.get_rendered_card_count() == 3)
	var mode_label: Label = panel.get_node(
		"Center/Panel/Margin/VBox/ModeLabel"
	)
	assert(mode_label.text.contains("СПЕЦИАЛИЗАЦИЯ"))
	assert(not mode_label.text.contains("СОБЫТИЕ"))
	var cards: HBoxContainer = panel.get_node(
		"Center/Panel/Margin/VBox/CardsContainer"
	)
	for card_index: int in range(cards.get_child_count()):
		var button: Button = cards.get_child(card_index) as Button
		assert(button != null)
		assert(panel.get_rendered_card_group_id(card_index) == &"specialization")
		assert(button.text.contains("✦"))
		assert(button.text.contains("Цена: %d" % upgrades.get_current_cost()))
		assert(not button.text.contains("Заблокирует альтернативы"))
		assert(not button.text.contains("ТРЕБОВАНИЯ"))
	await _remove_game(game)


func _spawn_game(catalog: UpgradeCatalog) -> Node2D:
	assert(catalog.is_valid())
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	var upgrades: UpgradeSystem = game.get_node("UpgradeSystem")
	flow.start_delay_seconds = 0.0
	upgrades.catalog = catalog
	root.add_child(game)
	await process_frame
	await process_frame
	assert(flow.state == GameFlowController.RunState.RUNNING)
	return game


func _remove_game(game: Node2D) -> void:
	paused = false
	game.queue_free()
	await process_frame


func _make_card(
	card_id: StringName,
	card_type: int,
	branch_id: StringName
) -> UpgradeDefinition:
	var definition := UpgradeDefinition.new()
	definition.card_id = card_id
	definition.branch_id = branch_id
	definition.title = String(card_id)
	definition.description = "UI integration test card"
	definition.card_type = card_type
	definition.repeat_limit = 1
	return definition


func _make_domain_scalar_effect() -> UpgradeEffectDefinition:
	var effect := UpgradeEffectDefinition.new()
	effect.effect_type = UpgradeEffectDefinition.EffectType.DOMAIN_SCALAR
	effect.target_id = &"ui_test_scalar"
	effect.scalar_value = 1.25
	return effect
