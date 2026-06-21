extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")
const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/common_repeatable_upgrade_catalog.tres"
)


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	await process_frame
	await process_frame

	var turrets: TurretUpgradeSystem = game.get_node("World/TurretSystem")
	_test_base_line_effects(turrets)
	_test_specialization_effects(turrets)
	_test_run_reset(turrets, flow)
	print("Turret upgrade system scenarios passed")
	quit()


func _test_base_line_effects(turrets: TurretUpgradeSystem) -> void:
	assert(turrets.get_current_damage() == 1)
	assert(is_equal_approx(turrets.get_current_cooldown(), 0.8))
	assert(is_equal_approx(turrets.get_current_range(), 360.0))
	assert(turrets.apply_upgrade_effect(_effect(&"turret_damage_basic")))
	assert(turrets.apply_upgrade_effect(_effect(&"turret_damage_advanced")))
	assert(turrets.get_current_damage() == 3)
	assert(turrets.apply_upgrade_effect(_effect(&"turret_cooldown_basic")))
	assert(turrets.apply_upgrade_effect(_effect(&"turret_cooldown_advanced")))
	assert(is_equal_approx(
		turrets.get_current_cooldown(),
		0.8 * 0.85 * 0.85
	))
	assert(turrets.apply_upgrade_effect(_effect(&"turret_range_basic")))
	assert(turrets.apply_upgrade_effect(_effect(&"turret_range_advanced")))
	assert(is_equal_approx(
		turrets.get_current_range(),
		360.0 * 1.2 * 1.2
	))


func _test_specialization_effects(turrets: TurretUpgradeSystem) -> void:
	assert(turrets.apply_upgrade_effect(_effect(
		&"turret_specialization_heavy"
	)))
	assert(turrets.get_specialization_id() == TurretUpgradeRuntime.HEAVY)
	assert(turrets.get_current_damage() == 4)
	assert(turrets.apply_upgrade_effect(_effect(&"turret_heavy_piercing")))
	assert(turrets.apply_upgrade_effect(_effect(
		&"turret_heavy_explosive_fifth"
	)))
	assert(turrets.upgrades.piercing_enabled)
	assert(turrets.upgrades.explosive_fifth_enabled)


func _test_run_reset(
	turrets: TurretUpgradeSystem,
	flow: GameFlowController
) -> void:
	flow.start_run()
	await process_frame
	assert(turrets.get_current_damage() == 1)
	assert(is_equal_approx(turrets.get_current_cooldown(), 0.8))
	assert(is_equal_approx(turrets.get_current_range(), 360.0))
	assert(turrets.get_specialization_id() == &"")


func _effect(card_id: StringName) -> UpgradeEffectDefinition:
	var definition: UpgradeDefinition = CATALOG.get_definition(card_id)
	assert(definition != null)
	assert(definition.effect != null)
	return definition.effect
