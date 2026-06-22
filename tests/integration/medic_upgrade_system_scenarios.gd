extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	await process_frame
	await process_frame

	var upgrades: MedicUpgradeCoordinator = game.get_node("UpgradeSystem")
	var medical: MedicalStationSystem = game.get_node("World/MedicalStationSystem")
	var inventory: BuildableInventory = game.get_node("BuildableInventory")
	assert(upgrades != null)
	assert(medical != null)
	assert(upgrades.catalog.get_definition(&"medic_station") != null)
	_test_unlock_card(upgrades, inventory)
	_test_live_base_effects(upgrades, medical)
	_test_run_reset(medical)
	print("Medic upgrade integration scenarios passed")
	quit()


func _test_unlock_card(
	upgrades: MedicUpgradeCoordinator,
	inventory: BuildableInventory
) -> void:
	var definition: UpgradeDefinition = upgrades.catalog.get_definition(&"medic_station")
	var applier: UpgradeEffectApplier = upgrades.get("_effect_applier") as UpgradeEffectApplier
	assert(applier != null)
	assert(inventory.get_unlocked_count(BuildableType.Id.MEDICAL_STATION) == 0)
	assert(applier.can_apply(definition))
	assert(applier.apply_effect(definition))
	assert(inventory.get_unlocked_count(BuildableType.Id.MEDICAL_STATION) == 1)
	assert(not applier.can_apply(definition))


func _test_live_base_effects(
	upgrades: MedicUpgradeCoordinator,
	medical: MedicalStationSystem
) -> void:
	var applier: UpgradeEffectApplier = upgrades.get("_effect_applier") as UpgradeEffectApplier
	assert(medical.get_current_heal_amount() == 1)
	assert(is_equal_approx(medical.get_current_heal_interval(), 5.0))
	assert(is_equal_approx(medical.get_current_heal_range(), 18.0))

	assert(applier.apply_effect(upgrades.catalog.get_definition(
		&"medic_heal_amount_basic"
	)))
	assert(applier.apply_effect(upgrades.catalog.get_definition(
		&"medic_heal_amount_advanced"
	)))
	assert(medical.get_current_heal_amount() == 3)

	assert(applier.apply_effect(upgrades.catalog.get_definition(
		&"medic_heal_speed_basic"
	)))
	assert(applier.apply_effect(upgrades.catalog.get_definition(
		&"medic_heal_speed_advanced"
	)))
	assert(is_equal_approx(medical.get_current_heal_interval(), 5.0 / 1.4))

	assert(applier.apply_effect(upgrades.catalog.get_definition(
		&"medic_heal_range_basic"
	)))
	assert(applier.apply_effect(upgrades.catalog.get_definition(
		&"medic_heal_range_advanced"
	)))
	assert(is_equal_approx(medical.get_current_heal_range(), 18.0 * 1.3))


func _test_run_reset(medical: MedicalStationSystem) -> void:
	medical.reset_upgrade_runtime()
	assert(medical.get_current_heal_amount() == 1)
	assert(is_equal_approx(medical.get_current_heal_interval(), 5.0))
	assert(is_equal_approx(medical.get_current_heal_range(), 18.0))
	assert(medical.upgrades.specialization_id == &"")
