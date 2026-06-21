extends SceneTree

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/common_repeatable_upgrade_catalog.tres"
)


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	_test_catalog_and_common_pairs()
	_test_repeat_limits_reset()
	_test_turret_post_rules()
	_test_fourth_turret_requirements()
	_test_common_cards_do_not_change_branch_progress()
	_test_effect_validation()
	print("Common repeatable upgrade scenarios passed")
	quit()


func _test_catalog_and_common_pairs() -> void:
	assert(CATALOG.is_valid())
	var runtime := UpgradeRuntime.new()
	var move_power: UpgradeDefinition = CATALOG.get_definition(
		&"common_move_speed_power"
	)
	var respawn_turbo: UpgradeDefinition = CATALOG.get_definition(
		&"common_respawn_turbo"
	)
	assert(not CATALOG.is_available(move_power, runtime))
	assert(not CATALOG.is_available(respawn_turbo, runtime))
	assert(runtime.record_card(CATALOG.get_definition(&"common_move_speed")))
	assert(runtime.record_card(CATALOG.get_definition(&"common_respawn_speed")))
	assert(CATALOG.is_available(move_power, runtime))
	assert(CATALOG.is_available(respawn_turbo, runtime))


func _test_repeat_limits_reset() -> void:
	var runtime := UpgradeRuntime.new()
	var add_defender: UpgradeDefinition = CATALOG.get_definition(
		&"common_add_defender"
	)
	for _index: int in range(5):
		assert(runtime.record_card(add_defender))
	assert(runtime.get_repeat_count(add_defender.card_id) == 5)
	assert(not runtime.record_card(add_defender))
	assert(not CATALOG.is_available(add_defender, runtime))
	runtime.reset_for_run()
	assert(runtime.get_repeat_count(add_defender.card_id) == 0)
	assert(CATALOG.is_available(add_defender, runtime))


func _test_turret_post_rules() -> void:
	var runtime := UpgradeRuntime.new()
	var post: UpgradeDefinition = CATALOG.get_definition(&"common_turret_post")
	var basic: UpgradeDefinition = CATALOG.get_definition(&"turret_basic_damage")
	assert(not CATALOG.is_available(basic, runtime))
	assert(runtime.record_card(post))
	assert(CATALOG.is_available(basic, runtime))
	assert(runtime.get_branch_progress(&"turret") == 0)
	assert(runtime.record_card(post))
	assert(runtime.record_card(post))
	assert(runtime.get_repeat_count(post.card_id) == 3)
	assert(not CATALOG.is_available(post, runtime))
	assert(runtime.get_branch_progress(&"turret") == 0)


func _test_fourth_turret_requirements() -> void:
	var runtime := UpgradeRuntime.new()
	var fourth: UpgradeDefinition = CATALOG.get_definition(
		&"common_fourth_turret"
	)
	var post: UpgradeDefinition = CATALOG.get_definition(&"common_turret_post")
	for _index: int in range(3):
		assert(runtime.record_card(post))
	assert(not CATALOG.is_available(fourth, runtime))
	assert(runtime.record_card(CATALOG.get_definition(&"turret_basic_damage")))
	assert(runtime.record_card(CATALOG.get_definition(&"turret_advanced_rate")))
	assert(not CATALOG.is_available(fourth, runtime))
	assert(runtime.record_card(CATALOG.get_definition(
		&"turret_specialization_heavy"
	)))
	assert(CATALOG.is_available(fourth, runtime))


func _test_common_cards_do_not_change_branch_progress() -> void:
	var runtime := UpgradeRuntime.new()
	assert(runtime.record_card(CATALOG.get_definition(&"common_move_speed")))
	assert(runtime.record_card(CATALOG.get_definition(&"common_respawn_speed")))
	assert(runtime.get_ready_specialization_branches().is_empty())
	assert(runtime.get_branch_progress(&"melee") == 0)
	assert(runtime.get_branch_progress(&"turret") == 0)


func _test_effect_validation() -> void:
	var add_effect := UpgradeEffectDefinition.new()
	add_effect.effect_type = UpgradeEffectDefinition.EffectType.ADD_DEFENDER
	add_effect.integer_value = 1
	assert(add_effect.is_valid())
	add_effect.integer_value = 0
	assert(not add_effect.is_valid())
	var move_effect := UpgradeEffectDefinition.new()
	move_effect.effect_type = (
		UpgradeEffectDefinition.EffectType.CREW_MOVE_SPEED_MULTIPLIER
	)
	move_effect.scalar_value = 1.15
	assert(move_effect.is_valid())
	var respawn_effect := UpgradeEffectDefinition.new()
	respawn_effect.effect_type = (
		UpgradeEffectDefinition.EffectType.CREW_RESPAWN_MULTIPLIER
	)
	respawn_effect.scalar_value = 0.8
	assert(respawn_effect.is_valid())
