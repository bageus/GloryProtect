extends SceneTree


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	_test_repeat_limits_reset()
	_test_common_cards_do_not_change_branch_progress()
	_test_add_defender_effect_validation()
	print("Common repeatable upgrade scenarios passed")
	quit()


func _test_repeat_limits_reset() -> void:
	var runtime := UpgradeRuntime.new()
	var add_defender := _make_card(&"common_add_defender", 5)
	for _index: int in range(5):
		assert(runtime.record_card(add_defender))
	assert(runtime.get_repeat_count(add_defender.card_id) == 5)
	assert(not runtime.record_card(add_defender))
	runtime.reset_for_run()
	assert(runtime.get_repeat_count(add_defender.card_id) == 0)


func _test_common_cards_do_not_change_branch_progress() -> void:
	var runtime := UpgradeRuntime.new()
	var common := _make_card(&"common_move_speed", 1)
	common.card_type = UpgradeDefinition.CardType.GENERAL
	common.branch_id = &""
	assert(runtime.record_card(common))
	assert(runtime.get_ready_specialization_branches().is_empty())
	assert(runtime.get_branch_progress(&"melee") == 0)
	assert(runtime.get_branch_progress(&"turret") == 0)


func _test_add_defender_effect_validation() -> void:
	var effect := UpgradeEffectDefinition.new()
	effect.effect_type = UpgradeEffectDefinition.EffectType.ADD_DEFENDER
	effect.integer_value = 1
	assert(effect.is_valid())
	effect.integer_value = 0
	assert(not effect.is_valid())


func _make_card(card_id: StringName, repeat_limit: int) -> UpgradeDefinition:
	var definition := UpgradeDefinition.new()
	definition.card_id = card_id
	definition.branch_id = &"common"
	definition.title = String(card_id)
	definition.card_type = UpgradeDefinition.CardType.UNLOCK
	definition.repeat_limit = repeat_limit
	return definition
