extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	await _test_domain_effects_and_limits()
	await _test_fresh_run_starts_clean()
	print("Common repeatable upgrade integration scenarios passed")
	quit()


func _test_domain_effects_and_limits() -> void:
	var game: Node = GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var upgrades: UpgradeSystem = game.get_node("UpgradeSystem")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var roles: CrewRoleManager = game.get_node(
		"World/Platform/CrewRoleManager"
	)
	var replacements: CrewReplacementController = game.get_node(
		"CrewReplacementController"
	)
	var buildables: BuildableInventory = game.get_node("BuildableInventory")
	var runtime: UpgradeRuntime = upgrades.get_runtime()
	var catalog: UpgradeCatalog = upgrades.catalog
	var applier := UpgradeEffectApplier.new()
	applier.configure(buildables, runtime, crew, replacements)

	assert(catalog.is_valid())
	assert(crew.get_total_count() == 3)
	var add_defender: UpgradeDefinition = catalog.get_definition(
		&"common_add_defender"
	)
	for expected_count: int in range(4, 9):
		_apply_card(add_defender, applier, runtime)
		assert(crew.get_total_count() == expected_count)
		var added_id: int = expected_count - 1
		assert(crew.get_defender(added_id) != null)
		assert(roles.get_assignment(added_id) != null)
	assert(not applier.can_apply(add_defender))
	assert(runtime.get_repeat_count(add_defender.card_id) == 5)

	_apply_card(
		catalog.get_definition(&"common_move_speed_basic"),
		applier,
		runtime
	)
	_apply_card(
		catalog.get_definition(&"common_move_speed_advanced"),
		applier,
		runtime
	)
	assert(is_equal_approx(
		crew.get_movement_speed_multiplier(),
		1.15 * 1.15
	))
	for defender: Defender in crew.get_all_defenders():
		assert(is_equal_approx(
			defender.movement.move_speed,
			crew.get_current_movement_speed()
		))

	_apply_card(
		catalog.get_definition(&"common_respawn_basic"),
		applier,
		runtime
	)
	_apply_card(
		catalog.get_definition(&"common_respawn_advanced"),
		applier,
		runtime
	)
	assert(is_equal_approx(
		replacements.get_respawn_time_multiplier(),
		0.75 * 0.75
	))
	assert(is_equal_approx(
		replacements.get_current_respawn_delay(),
		replacements.balance.replacement_delay_seconds * 0.75 * 0.75
	))

	var post: UpgradeDefinition = catalog.get_definition(&"turret_post")
	for expected_turrets: int in range(1, 4):
		_apply_card(post, applier, runtime)
		assert(buildables.get_unlocked_count(BuildableType.Id.TURRET) == expected_turrets)
	assert(runtime.get_branch_progress(&"turret") == 0)
	assert(buildables.balance.turret_damage == 1)
	assert(not catalog.is_available(post, runtime))
	assert(applier.can_apply(post))

	var fourth: UpgradeDefinition = catalog.get_definition(&"turret_fourth")
	assert(not catalog.is_available(fourth, runtime))
	_apply_card(
		catalog.get_definition(&"turret_damage_basic"),
		applier,
		runtime
	)
	_apply_card(
		catalog.get_definition(&"turret_damage_advanced"),
		applier,
		runtime
	)
	assert(not catalog.is_available(fourth, runtime))
	_apply_card(
		catalog.get_definition(&"turret_specialization_heavy"),
		applier,
		runtime
	)
	assert(catalog.is_available(fourth, runtime))
	_apply_card(fourth, applier, runtime)
	assert(buildables.get_unlocked_count(BuildableType.Id.TURRET) == 4)
	assert(not catalog.is_available(fourth, runtime))

	game.queue_free()
	await process_frame
	await process_frame


func _test_fresh_run_starts_clean() -> void:
	var game: Node = GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var upgrades: UpgradeSystem = game.get_node("UpgradeSystem")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var replacements: CrewReplacementController = game.get_node(
		"CrewReplacementController"
	)
	var buildables: BuildableInventory = game.get_node("BuildableInventory")

	assert(crew.get_total_count() == 3)
	assert(is_equal_approx(crew.get_movement_speed_multiplier(), 1.0))
	assert(is_equal_approx(replacements.get_respawn_time_multiplier(), 1.0))
	assert(buildables.get_unlocked_count(BuildableType.Id.TURRET) == 0)
	assert(upgrades.get_runtime().get_selected_cards().is_empty())

	game.queue_free()
	await process_frame


func _apply_card(
	definition: UpgradeDefinition,
	applier: UpgradeEffectApplier,
	runtime: UpgradeRuntime
) -> void:
	assert(definition != null)
	assert(applier.can_apply(definition))
	assert(applier.apply_effect(definition))
	assert(runtime.record_card(definition))
