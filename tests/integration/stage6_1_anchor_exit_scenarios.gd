extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var flow: GameFlowController = game.get_node("GameFlowController")
	var wind: WindSystem = game.get_node("WindSystem")
	var platform: PlatformController = game.get_node("World/Platform")
	var anchors := game.get_node("World/AnchorSystem") as CombatAnchorHostSystem
	var paths: AnchorPathRegistry = game.get_node("World/AnchorPathRegistry")
	var spawn: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var combat: CombatAnchorSystem = game.get_node("World/CombatAnchorSystem")
	var visual := anchors.get_node(
		"AnchorVisualController"
	) as CombatAnchorVisualController

	flow.state = GameFlowController.RunState.RUNNING
	wind.balance.level_forces = PackedFloat32Array([0.0, 0.0, 0.0])
	wind.balance.fluctuation_force = 0.0
	wind.set_debug_state(1, 1)
	platform.position.x = 0.0
	platform.horizontal_velocity = 0.0
	spawn.set_physics_process(false)
	game.get_node("World/FlyingEnemySpawnDirector").set_physics_process(false)
	game.get_node("World/StrategicWaveDirector").set_physics_process(false)
	game.get_node("World/StrategicGroupMutationController").set_physics_process(false)

	anchors.toggle_anchor(2)
	await _wait_physics_frames(120)
	assert(paths.get_available_count() >= 1)
	var path: AnchorPathSnapshot = paths.get_available_paths()[0]

	combat.upgrades.specialization_id = CombatAnchorUpgradeRuntime.ELECTRIC
	combat.upgrades_changed.emit()
	await process_frame
	assert(visual.is_electric_visual_active(path.anchor_id))

	var entry_local_x: float = path.platform_point.x - platform.global_position.x
	var defender: Defender = crew.get_defender(2)
	defender.teleport_to(entry_local_x)

	var enemy: BoardingEnemy = spawn.spawn_now()
	assert(enemy != null)
	enemy.health.configure(10)
	enemy.global_position = path.ground_point
	await _wait_for_state(enemy, BoardingEnemyController.State.CLIMBING, 30)
	await _wait_until_boarded(enemy, 360)
	assert(enemy.is_on_platform())

	print("Stage 6.1 anchor exit scenarios passed")
	quit()


func _wait_for_state(
	enemy: BoardingEnemy,
	state: int,
	max_frames: int
) -> void:
	for _frame: int in range(max_frames):
		if enemy.get_state() == state:
			return
		await physics_frame
	assert(false, "Enemy did not enter expected state")


func _wait_until_boarded(
	enemy: BoardingEnemy,
	max_frames: int
) -> void:
	for _frame: int in range(max_frames):
		if enemy.is_on_platform():
			return
		await physics_frame
	assert(false, "Defender at post blocked the rope exit")


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await physics_frame
