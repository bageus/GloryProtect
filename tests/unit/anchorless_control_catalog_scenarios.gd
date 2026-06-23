extends SceneTree

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/anchorless_control_upgrade_catalog.tres"
)
const DRAW_BALANCE: UpgradeDrawBalance = preload(
	"res://resources/upgrades/upgrade_draw_balance.tres"
)


func _init() -> void:
	_test_base_and_advanced_lines()
	_test_individual_prerequisite()
	_test_specialization_event_and_locking()
	_test_branch_weights()
	print("Anchorless control catalog scenarios passed")
	quit()


func _test_base_and_advanced_lines() -> void:
	assert(CATALOG.is_valid())
	var runtime := UpgradeRuntime.new()
	var steering_basic: UpgradeDefinition = CATALOG.get_definition(
		&"anchorless_steering_force_basic"
	)
	var steering_advanced: UpgradeDefinition = CATALOG.get_definition(
		&"anchorless_steering_force_advanced"
	)
	var wind_basic: UpgradeDefinition = CATALOG.get_definition(
		&"anchorless_wind_reduction_basic"
	)
	assert(CATALOG.is_available(steering_basic, runtime))
	assert(not CATALOG.is_available(steering_advanced, runtime))
	assert(runtime.record_card(steering_basic))
	assert(CATALOG.is_available(steering_advanced, runtime))
	assert(runtime.record_card(wind_basic))
	assert(runtime.is_branch_ready_for_specialization(&"steering"))


func _test_individual_prerequisite() -> void:
	var runtime := UpgradeRuntime.new()
	var automatic: UpgradeDefinition = CATALOG.get_definition(
		&"anchorless_auto_steering"
	)
	assert(not CATALOG.is_available(automatic, runtime))
	assert(runtime.record_card(CATALOG.get_definition(
		&"anchorless_release_drag_basic"
	)))
	assert(runtime.record_card(CATALOG.get_definition(
		&"anchorless_release_drag_advanced"
	)))
	assert(CATALOG.is_available(automatic, runtime))


func _test_specialization_event_and_locking() -> void:
	var runtime := UpgradeRuntime.new()
	assert(runtime.record_card(CATALOG.get_definition(
		&"anchorless_steering_force_basic"
	)))
	assert(runtime.record_card(CATALOG.get_definition(
		&"anchorless_wind_reduction_basic"
	)))
	var generator := UpgradeSpecializationEventGenerator.new()
	generator.configure(CATALOG, runtime, 26)
	var offer: Array[UpgradeDefinition] = generator.generate_event_offer(&"steering")
	assert(offer.size() == 3)
	for definition: UpgradeDefinition in offer:
		assert(definition.branch_id == &"steering")
		assert(definition.card_type == UpgradeDefinition.CardType.SPECIALIZATION)
	var speed: UpgradeDefinition = CATALOG.get_definition(
		&"anchorless_specialization_speed"
	)
	var precise: UpgradeDefinition = CATALOG.get_definition(
		&"anchorless_specialization_precise"
	)
	assert(runtime.record_card(speed))
	assert(runtime.get_specialization(&"steering") == speed.card_id)
	assert(runtime.is_specialization_closed(precise.card_id))
	assert(CATALOG.is_available(CATALOG.get_definition(
		&"anchorless_speed_long_flight_restore"
	), runtime))
	assert(not CATALOG.is_available(CATALOG.get_definition(
		&"anchorless_precise_recharge"
	), runtime))


func _test_branch_weights() -> void:
	var runtime := UpgradeRuntime.new()
	var generator := UpgradeDrawGenerator.new()
	generator.configure(DRAW_BALANCE, CATALOG, runtime, 13)
	assert(generator.get_branch_weight(&"steering") == 10)
	assert(generator.get_branch_weight(&"anchors") == 10)
	assert(runtime.record_card(CATALOG.get_definition(
		&"anchorless_steering_force_basic"
	)))
	generator.apply_selected_card(CATALOG.get_definition(
		&"anchorless_steering_force_basic"
	))
	assert(generator.get_branch_weight(&"steering") == 13)
	assert(generator.get_branch_weight(&"anchors") == 9)
	assert(generator.get_branch_weight(&"turret") == 9)
