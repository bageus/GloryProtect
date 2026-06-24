extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run_scenario")


func _run_scenario() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	flow.state = GameFlowController.RunState.RUNNING

	var upgrade_system: UpgradeSystem = game.get_node("UpgradeSystem")
	var anchors: CombatAnchorSystem = game.get_node("World/CombatAnchorSystem")
	var host: CombatAnchorHostSystem = game.get_node("World/AnchorSystem")
	var definition: UpgradeDefinition = upgrade_system.catalog.get_definition(
		&"anchor_overload_basic"
	)
	assert(definition != null)
	assert(upgrade_system._effect_applier.can_apply(definition))
	assert(upgrade_system._effect_applier.apply_effect(definition))
	assert(is_equal_approx(anchors.upgrades.overload_bonus_seconds, 1.0))
	assert(is_equal_approx(
		host.get_effective_overload_duration(),
		host.balance.overload_duration + 1.0
	))

	var periodic: UpgradeDefinition = upgrade_system.catalog.get_definition(
		&"anchor_periodic_electric_basic"
	)
	assert(upgrade_system._effect_applier.can_apply(periodic))
	assert(upgrade_system._effect_applier.apply_effect(periodic))
	assert(anchors.upgrades.periodic_electric_enabled)

	print("Combat anchor upgrade routing scenarios passed")
	quit()
