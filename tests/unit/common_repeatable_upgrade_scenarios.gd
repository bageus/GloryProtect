extends SceneTree

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/game_upgrade_catalog.tres"
)
const DRAW_BALANCE: UpgradeDrawBalance = preload(
	"res://resources/upgrades/upgrade_draw_balance.tres"
)


func _init() -> void:
	_test_catalog_and_opening_rules()
	_test_repeat_limits_and_fourth_turret_requirements()
	_test_opening_and_general_cards_do_not_change_weights()
	_test_offer_has_unique_card_ids()
	_test_common_values_and_reset()
	print("Common repeatable upgrade scenarios passed")
	quit()


func _test_catalog_and_opening_rules() -> void:
	assert(CATALOG.is_valid())
	var runtime := UpgradeRuntime.new()
	var post: UpgradeDefinition = CATALOG.get_definition(&"turret_post")
	assert(post != null)
	assert(post.card_type == UpgradeDefinition.CardType.UNLOCK)
	assert(post.repeat_limit == 3)

	var basic_ids: Array[StringName] = [
		&"turret_damage_basic",
		&"turret_cooldown_basic",
		&"turret_range_basic",
	]
	for card_id: StringName in basic_ids:
		assert(not CATALOG.is_available(CATALOG.get_definition(card_id), runtime))

	assert(runtime.record_card(post))
	assert(runtime.get_branch_progress(&"turret") == 0)
	for card_id: StringName in basic_ids:
		assert(CATALOG.is_available(CATALOG.get_definition(card_id), runtime))

	assert(not CATALOG.is_available(
		CATALOG.get_definition(&"turret_damage_advanced"),
		runtime
	))
	assert(runtime.record_card(CATALOG.get_definition(&"turret_damage_basic")))
	assert(CATALOG.is_available(
		CATALOG.get_definition(&"turret_damage_advanced"),
		runtime
	))


func _test_repeat_limits_and_fourth_turret_requirements() -> void:
	var runtime := UpgradeRuntime.new()
	var post: UpgradeDefinition = CATALOG.get_definition(&"turret_post")
	var fourth: UpgradeDefinition = CATALOG.get_definition(&"turret_fourth")
	assert(fourth.card_type == UpgradeDefinition.CardType.INDIVIDUAL)

	for _index: int in range(3):
		assert(runtime.record_card(post))
	assert(runtime.get_repeat_count(post.card_id) == 3)
	assert(not runtime.record_card(post))
	assert(not CATALOG.is_available(fourth, runtime))

	assert(runtime.record_card(CATALOG.get_definition(&"turret_damage_basic")))
	assert(runtime.record_card(CATALOG.get_definition(&"turret_damage_advanced")))
	assert(not CATALOG.is_available(fourth, runtime))

	assert(runtime.record_card(
		CATALOG.get_definition(&"turret_specialization_heavy")
	))
	assert(CATALOG.is_available(fourth, runtime))
	assert(runtime.record_card(fourth))
	assert(not CATALOG.is_available(fourth, runtime))


func _test_opening_and_general_cards_do_not_change_weights() -> void:
	var runtime := UpgradeRuntime.new()
	var generator := UpgradeDrawGenerator.new()
	generator.configure(DRAW_BALANCE, CATALOG, runtime, 3901)
	var turret_weight: int = generator.get_branch_weight(&"turret")
	var anchor_weight: int = generator.get_branch_weight(&"anchors")

	var post: UpgradeDefinition = CATALOG.get_definition(&"turret_post")
	generator.apply_selected_card(post)
	assert(generator.get_branch_weight(&"turret") == turret_weight)
	assert(generator.get_branch_weight(&"anchors") == anchor_weight)

	var general: UpgradeDefinition = CATALOG.get_definition(
		&"common_move_speed_basic"
	)
	assert(runtime.record_card(general))
	generator.apply_selected_card(general)
	assert(runtime.get_branch_progress(&"turret") == 0)
	assert(generator.get_branch_weight(&"turret") == turret_weight)
	assert(generator.get_branch_weight(&"anchors") == anchor_weight)


func _test_offer_has_unique_card_ids() -> void:
	var runtime := UpgradeRuntime.new()
	var generator := UpgradeDrawGenerator.new()
	generator.configure(DRAW_BALANCE, CATALOG, runtime, 7719)
	for seed: int in range(1, 40):
		generator.set_seed(seed)
		var offer: Array[UpgradeDefinition] = generator.generate_offer()
		var seen: Dictionary[StringName, bool] = {}
		for definition: UpgradeDefinition in offer:
			assert(not seen.has(definition.card_id))
			seen[definition.card_id] = true


func _test_common_values_and_reset() -> void:
	var add_defender: UpgradeDefinition = CATALOG.get_definition(
		&"common_add_defender"
	)
	assert(add_defender.repeat_limit == 5)
	assert(CATALOG.get_definition(
		&"common_move_speed_basic"
	).effect.scalar_value == 1.15)
	assert(CATALOG.get_definition(
		&"common_respawn_basic"
	).effect.scalar_value == 0.75)

	var runtime := UpgradeRuntime.new()
	for _index: int in range(5):
		assert(runtime.record_card(add_defender))
	assert(runtime.get_repeat_count(add_defender.card_id) == 5)
	runtime.reset_for_run()
	assert(runtime.get_repeat_count(add_defender.card_id) == 0)
	assert(runtime.get_ready_specialization_branches().is_empty())
