extends SceneTree

const GAME_SCENE := preload(
	"res://scenes/game/game_root_with_flyers.tscn"
)
const TURRET_RANGE_OUTLINE_COLOR := Color(0.38, 0.88, 1.0, 0.68)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var flow: GameFlowController = game.get_node("GameFlowController")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var platform: PlatformController = game.get_node("World/Platform")
	var selection := game.get_node(
		"CrewDebugInput"
	) as CrewSelectionController
	var crew_panel := game.get_node(
		"CanvasLayer/PrototypeHUD/CrewCommandPanel"
	) as ShooterRangeCrewCommandPanel
	var placement := game.get_node(
		"BuildablePlacementController"
	) as BuildablePlacementController

	_disable_spawners(game)
	flow.state = GameFlowController.RunState.RUNNING
	await process_frame

	var defender: Defender = crew.get_defender(0)
	var visual := defender.visual as ShooterRangeDefenderVisual
	var shooter := (
		defender.shooter_combat
		as EffectiveRangeShooterCombatController
	)
	assert(visual != null)
	assert(shooter != null)
	assert(defender.ranged.profile != null)

	var base_range: float = shooter.base_profile.maximum_range
	assert(is_equal_approx(
		defender.ranged.profile.maximum_range,
		base_range
	))
	assert(not visual.is_attack_range_visible())

	assert(crew.apply_shooter_flag(&"shooter_role_unlocked"))
	assert(crew_panel.request_defender_type(
		defender.defender_id,
		CrewRole.Id.SHOOTER
	))
	assert(selection.select_defender(defender.defender_id))
	crew_panel.open_defender_command_context(defender.defender_id)
	await process_frame

	assert(crew_panel._view.is_context_visible())
	assert(visual.is_attack_range_visible())
	assert(is_equal_approx(
		visual.get_displayed_attack_range(),
		base_range
	))
	assert(not visual.get_attack_range_outline_color().is_equal_approx(
		TURRET_RANGE_OUTLINE_COLOR
	))

	var previous_center: Vector2 = visual.get_attack_range_center_global()
	defender.teleport_to(defender.position.x + 96.0)
	await process_frame
	assert(visual.get_attack_range_center_global().is_equal_approx(
		defender.global_position
	))
	assert(not visual.get_attack_range_center_global().is_equal_approx(
		previous_center
	))

	assert(crew.apply_shooter_scalar(
		&"shooter_range_multiplier",
		1.2
	))
	await process_frame
	var upgraded_range: float = base_range * 1.2
	assert(is_equal_approx(
		defender.ranged.profile.maximum_range,
		upgraded_range
	))
	assert(is_equal_approx(
		visual.get_displayed_attack_range(),
		upgraded_range
	))

	assert(crew.apply_shooter_flag(
		&"shooter_specialization_sniper"
	))
	await process_frame
	var sniper_range: float = base_range * 1.3
	assert(is_equal_approx(
		defender.ranged.profile.maximum_range,
		sniper_range
	))
	assert(is_equal_approx(
		visual.get_displayed_attack_range(),
		sniper_range
	))

	crew_panel.close_defender_command_context()
	await process_frame
	assert(not visual.is_attack_range_visible())

	assert(crew_panel.request_defender_type(
		defender.defender_id,
		CrewRole.Id.FREE_FIGHTER
	))
	crew_panel.open_defender_command_context(defender.defender_id)
	await process_frame
	assert(not visual.is_attack_range_visible())

	assert(crew_panel.request_defender_type(
		defender.defender_id,
		CrewRole.Id.SHOOTER
	))
	crew_panel.open_defender_command_context(defender.defender_id)
	await process_frame
	assert(visual.is_attack_range_visible())
	assert(_select_empty_platform_cell(placement, platform))
	await process_frame
	assert(not crew_panel._view.is_context_visible())
	assert(not visual.is_attack_range_visible())

	assert(selection.select_defender(defender.defender_id))
	crew_panel.open_defender_command_context(defender.defender_id)
	await process_frame
	assert(visual.is_attack_range_visible())
	defender.health.set_health(0)
	await process_frame
	assert(not crew_panel._view.is_context_visible())
	assert(not visual.is_attack_range_visible())

	print("Shooter effective range indicator scenarios passed")
	quit()


func _select_empty_platform_cell(
	placement: BuildablePlacementController,
	platform: PlatformController
) -> bool:
	for cell_index: int in range(platform.get_cell_count()):
		if placement.select_empty_cell(cell_index):
			return true
	return false


func _disable_spawners(game: Node) -> void:
	var paths: Array[NodePath] = [
		NodePath("World/BoardingSpawnDirector"),
		NodePath("World/FlyingEnemySpawnDirector"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
	]
	for path: NodePath in paths:
		if not game.has_node(path):
			continue
		var node: Node = game.get_node(path)
		node.set_process(false)
		node.set_physics_process(false)
