extends SceneTree

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/technical_upgrade_catalog.tres"
)


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	_test_branch_progress_and_three_choices()
	_test_opening_and_general_do_not_count()
	_test_selection_locks_alternatives_and_opens_extras()
	_test_multiple_ready_branches_are_preserved()
	print("Upgrade specialization event scenarios passed")
	quit()


func _test_branch_progress_and_three_choices() -> void:
	var runtime := UpgradeRuntime.new()
	var generator := UpgradeSpecializationEventGenerator.new()
	generator.configure(CATALOG, runtime, 17)
	assert(runtime.record_card(CATALOG.get_definition(&"tech_unlock_turret")))
	assert(runtime.record_card(CATALOG.get_definition(&"tech_turret_basic")))
	assert(runtime.get_branch_progress(&"turret") == 1)
	assert(not runtime.is_branch_ready_for_specialization(&"turret"))
	assert(runtime.record_card(CATALOG.get_definition(&"tech_turret_advanced")))
	assert(runtime.get_branch_progress(&"turret") == 2)
	assert(runtime.is_branch_ready_for_specialization(&"turret"))
	var offer: Array[UpgradeDefinition] = generator.generate_event_offer(&"turret")
	assert(offer.size() == 3)
	for definition: UpgradeDefinition in offer:
		assert(definition.card_type == UpgradeDefinition.CardType.SPECIALIZATION)
		assert(definition.branch_id == &"turret")


func _test_opening_and_general_do_not_count() -> void:
	var runtime := UpgradeRuntime.new()
	assert(runtime.record_card(CATALOG.get_definition(&"tech_unlock_turret")))
	assert(runtime.record_card(CATALOG.get_definition(&"tech_general")))
	assert(runtime.get_branch_progress(&"turret") == 0)
	assert(runtime.get_ready_specialization_branches().is_empty())


func _test_selection_locks_alternatives_and_opens_extras() -> void:
	var runtime := UpgradeRuntime.new()
	assert(runtime.record_card(CATALOG.get_definition(&"tech_unlock_turret")))
	assert(runtime.record_card(CATALOG.get_definition(&"tech_turret_basic")))
	assert(runtime.record_card(CATALOG.get_definition(&"tech_turret_advanced")))
	var heavy: UpgradeDefinition = CATALOG.get_definition(&"tech_turret_heavy")
	assert(runtime.record_card(heavy))
	assert(runtime.get_specialization(&"turret") == &"tech_turret_heavy")
	assert(runtime.is_specialization_closed(&"tech_turret_rapid"))
	assert(runtime.is_specialization_closed(&"tech_turret_electric"))
	assert(not runtime.is_branch_ready_for_specialization(&"turret"))
	assert(CATALOG.is_available(
		CATALOG.get_definition(&"tech_turret_heavy_extra"),
		runtime
	))
	assert(CATALOG.is_available(
		CATALOG.get_definition(&"tech_turret_heavy_extra_b"),
		runtime
	))


func _test_multiple_ready_branches_are_preserved() -> void:
	var catalog := _make_two_branch_catalog()
	var runtime := UpgradeRuntime.new()
	for definition: UpgradeDefinition in catalog.definitions:
		if definition.card_type == UpgradeDefinition.CardType.BASIC:
			assert(runtime.record_card(definition))
	assert(runtime.get_ready_specialization_branches().size() == 2)
	var generator := UpgradeSpecializationEventGenerator.new()
	generator.configure(catalog, runtime, 123)
	var selected_branch: StringName = generator.choose_ready_branch()
	assert(selected_branch in [&"alpha", &"beta"])
	var selected_offer: Array[UpgradeDefinition] = (
		generator.generate_event_offer(selected_branch)
	)
	assert(selected_offer.size() == 3)
	assert(runtime.record_card(selected_offer[0]))
	var remaining: Array[StringName] = runtime.get_ready_specialization_branches()
	assert(remaining.size() == 1)
	assert(remaining[0] != selected_branch)


func _make_two_branch_catalog() -> UpgradeCatalog:
	var catalog := UpgradeCatalog.new()
	for branch_id: StringName in [&"alpha", &"beta"]:
		catalog.definitions.append(_make_card(
			StringName("%s_basic_a" % branch_id),
			branch_id,
			UpgradeDefinition.CardType.BASIC
		))
		catalog.definitions.append(_make_card(
			StringName("%s_basic_b" % branch_id),
			branch_id,
			UpgradeDefinition.CardType.BASIC
		))
		for index: int in range(3):
			var specialization := _make_card(
				StringName("%s_spec_%d" % [branch_id, index]),
				branch_id,
				UpgradeDefinition.CardType.SPECIALIZATION
			)
			catalog.definitions.append(specialization)
	assert(catalog.is_valid())
	return catalog


func _make_card(
	card_id: StringName,
	branch_id: StringName,
	card_type: int
) -> UpgradeDefinition:
	var definition := UpgradeDefinition.new()
	definition.card_id = card_id
	definition.branch_id = branch_id
	definition.title = String(card_id)
	definition.card_type = card_type
	definition.repeat_limit = 1
	return definition
