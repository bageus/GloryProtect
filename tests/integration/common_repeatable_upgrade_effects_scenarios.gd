extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")
const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/common_repeatable_upgrade_catalog.tres"
)


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var inventory: BuildableInventory = game.get_node("BuildableInventory")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var replacements: CrewReplacementController = game.get_node(
		"CrewReplacementController"
	)
	var runtime := UpgradeRuntime.new()
	var applier := UpgradeEffectApplier.new()
	applier.configure(inventory, runtime, crew, replacements)

	_test_add_defenders(applier, crew)
	_test_turret_posts(applier, inventory)
	_test_speed_effects(applier, crew)
	_test_respawn_effects(applier, replacements)

	print("Common repeatable upgrade effect scenarios passed")
	quit()


func _test_add_defenders(
	applier: UpgradeEffectApplier,
	crew: CrewManager
) -> void:
	var definition: UpgradeDefinition = CATALOG.get_definition(
		&"common_add_defender"
	)
	assert(crew.get_total_count() == 3)
	for expected_count: int in range(4, 9):
		assert(applier.can_apply(definition))
		assert(applier.apply_effect(definition))
		assert(crew.get_total_count() == expected_count)
	assert(not crew.can_add_defender())
	assert(not applier.can_apply(definition))


func _test_turret_posts(
	applier: UpgradeEffectApplier,
	inventory: BuildableInventory
) -> void:
	var definition: UpgradeDefinition = CATALOG.get_definition(
		&"common_turret_post"
	)
	for expected_count: int in range(1, 4):
		print(
			"turret unlock before=%d max=%d can_apply=%s" % [
				inventory.get_unlocked_count(BuildableType.Id.TURRET),
				inventory.balance.turret_max_count,
				str(applier.can_apply(definition)),
			]
		)
		assert(applier.apply_effect(definition))
		assert(inventory.get_unlocked_count(BuildableType.Id.TURRET) == expected_count)
	assert(inventory.balance.turret_damage == 2)


func _test_speed_effects(
	applier: UpgradeEffectApplier,
	crew: CrewManager
) -> void:
	var base_speed: float = crew.balance.defender_move_speed
	assert(applier.apply_effect(CATALOG.get_definition(&"common_move_speed")))
	assert(is_equal_approx(crew.get_current_movement_speed(), base_speed * 1.15))
	assert(applier.apply_effect(CATALOG.get_definition(
		&"common_move_speed_power"
	)))
	assert(is_equal_approx(
		crew.get_current_movement_speed(),
		base_speed * 1.15 * 1.15
	))
	for defender: Defender in crew.get_all_defenders():
		assert(is_equal_approx(
			defender.movement.move_speed,
			crew.get_current_movement_speed()
		))


func _test_respawn_effects(
	applier: UpgradeEffectApplier,
	replacements: CrewReplacementController
) -> void:
	replacements.instant_respawn_for_tests = false
	var base_delay: float = replacements.balance.replacement_delay_seconds
	assert(applier.apply_effect(CATALOG.get_definition(
		&"common_respawn_speed"
	)))
	assert(is_equal_approx(
		replacements.get_current_respawn_delay(),
		base_delay * 0.8
	))
	assert(applier.apply_effect(CATALOG.get_definition(
		&"common_respawn_turbo"
	)))
	assert(is_equal_approx(
		replacements.get_current_respawn_delay(),
		base_delay * 0.8 * 0.8
	))
