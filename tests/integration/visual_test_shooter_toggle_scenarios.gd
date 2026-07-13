extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	flow.state = GameFlowController.RunState.RUNNING
	_disable_spawners(game)

	var panel := VisualUpgradeTestPanelShooterControls.new()
	game.add_child(panel)
	panel.configure(game)
	await process_frame

	var crew: CrewManager = game.get_node("World/Platform/CrewManager") as CrewManager
	var roles: ShooterCrewRoleManagerTestRun = game.get_node(
		"World/Platform/CrewRoleManager"
	) as ShooterCrewRoleManagerTestRun
	assert(crew != null)
	assert(roles != null)
	assert(not panel.is_shooter_enabled_for_tests())
	assert(not crew.is_shooter_role_unlocked())

	assert(panel.set_shooter_enabled_for_tests(true))
	await process_frame
	assert(panel.is_shooter_enabled_for_tests())
	assert(crew.is_shooter_role_unlocked())
	assert(roles.set_combat_role(0, CrewRole.Id.SHOOTER))
	assert(roles.get_combat_role(0) == CrewRole.Id.SHOOTER)

	assert(panel.toggle_upgrade_for_tests(&"shooter_damage_basic", true))
	assert(panel.is_upgrade_selected_for_tests(&"shooter_damage_basic"))
	assert(panel.set_shooter_enabled_for_tests(false))
	await process_frame
	assert(not panel.is_shooter_enabled_for_tests())
	assert(not panel.is_upgrade_selected_for_tests(&"shooter_damage_basic"))
	assert(not crew.is_shooter_role_unlocked())
	assert(roles.get_combat_role(0) == CrewRole.Id.FREE_FIGHTER)

	print("Visual test shooter toggle scenarios passed")
	quit()


func _disable_spawners(game: Node) -> void:
	var paths: Array[NodePath] = [
		NodePath("World/BoardingSpawnDirector"),
		NodePath("World/FlyingEnemySpawnDirector"),
		NodePath("World/StrategicWaveSystem"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
	]
	for path: NodePath in paths:
		if not game.has_node(path):
			continue
		var node: Node = game.get_node(path)
		node.set_process(false)
		node.set_physics_process(false)
