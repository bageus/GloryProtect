extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")
const GROUND_ARCHETYPES: Array[StringName] = [
	&"basic",
	&"runner",
	&"brute",
	&"rope_saboteur",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	flow.state = GameFlowController.RunState.RUNNING
	_disable_automatic_spawners(game)

	var wind: WindSystem = game.get_node("WindSystem")
	var platform: PlatformController = game.get_node("World/Platform")
	var anchors: AnchorSystem = game.get_node("World/AnchorSystem")
	var paths: AnchorPathRegistry = game.get_node("World/AnchorPathRegistry")
	var spawn: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	wind.balance.level_forces = PackedFloat32Array([0.0, 0.0, 0.0])
	wind.balance.fluctuation_force = 0.0
	wind.set_debug_state(1, 1)
	platform.position.x = 0.0
	platform.horizontal_velocity = 0.0

	await _attach_anchor(anchors, paths, 0)
	var enemies := _spawn_ground_archetypes(spawn, 1)
	await _wait_until_targets(enemies, 0)

	anchors.toggle_anchor(0)
	await _wait_until_path_closed(paths, 0)
	await _wait_until_anchor_state(anchors, 0, AnchorRuntime.State.STOWED)
	await _wait_until_all_waiting(enemies)

	await _attach_anchor(anchors, paths, 2)
	var replacement_path: AnchorPathSnapshot = paths.get_anchor_path(2)
	assert(replacement_path != null)
	var starting_distances: Dictionary[int, float] = {}
	for enemy: BoardingEnemy in enemies:
		starting_distances[enemy.enemy_id] = absf(
			enemy.global_position.x - replacement_path.ground_point.x
		)
	await _wait_until_targets(enemies, 2)
	await _wait_physics_frames(60)
	for enemy: BoardingEnemy in enemies:
		assert(enemy.health.is_alive())
		var current_distance: float = absf(
			enemy.global_position.x - replacement_path.ground_point.x
		)
		assert(current_distance < float(starting_distances[enemy.enemy_id]) - 1.0)

	_cleanup_enemies(enemies)
	await _wait_physics_frames(3)
	await _test_opposing_queues_can_reach_one_anchor(spawn, paths, 2)

	anchors.toggle_anchor(2)
	await _wait_until_path_closed(paths, 2)
	await _wait_until_anchor_state(anchors, 2, AnchorRuntime.State.STOWED)
	await _attach_anchor(anchors, paths, 2)
	var repeated := _spawn_ground_archetypes(spawn, -1)
	await _wait_until_targets(repeated, 2)
	var repeat_path: AnchorPathSnapshot = paths.get_anchor_path(2)
	assert(repeat_path != null)
	var repeat_start_x: Dictionary[int, float] = {}
	for enemy: BoardingEnemy in repeated:
		repeat_start_x[enemy.enemy_id] = enemy.global_position.x
	await _wait_physics_frames(45)
	for enemy: BoardingEnemy in repeated:
		assert(
			absf(enemy.global_position.x - float(repeat_start_x[enemy.enemy_id]))
			> 1.0
		)

	_cleanup_enemies(repeated)
	print("Anchor path recovery scenarios passed")
	quit()


func _spawn_ground_archetypes(
	spawn: BoardingSpawnDirector,
	side: int
) -> Array[BoardingEnemy]:
	var result: Array[BoardingEnemy] = []
	for archetype_id: StringName in GROUND_ARCHETYPES:
		var enemy: BoardingEnemy = spawn.spawn_debug_archetype(
			archetype_id,
			side
		)
		assert(enemy != null)
		result.append(enemy)
	return result


func _test_opposing_queues_can_reach_one_anchor(
	spawn: BoardingSpawnDirector,
	paths: AnchorPathRegistry,
	anchor_id: int
) -> void:
	var path: AnchorPathSnapshot = paths.get_anchor_path(anchor_id)
	assert(path != null)
	var left: BoardingEnemy = spawn.spawn_debug_archetype(&"basic", -1)
	var right: BoardingEnemy = spawn.spawn_debug_archetype(&"basic", 1)
	assert(left != null and right != null)
	left.global_position = path.ground_point + Vector2(-20.0, 0.0)
	right.global_position = path.ground_point + Vector2(20.0, 0.0)
	left.controller.selected_anchor_id = anchor_id
	right.controller.selected_anchor_id = anchor_id
	left.controller.state = BoardingEnemyController.State.RUNNING_TO_ANCHOR
	right.controller.state = BoardingEnemyController.State.RUNNING_TO_ANCHOR

	await _wait_physics_frames(30)
	assert(
		left.get_state() == BoardingEnemyController.State.CLIMBING
		or right.get_state() == BoardingEnemyController.State.CLIMBING
		or left.is_on_platform()
		or right.is_on_platform()
	)
	left.kill(&"test_cleanup")
	right.kill(&"test_cleanup")
	await _wait_physics_frames(3)


func _wait_until_targets(
	enemies: Array[BoardingEnemy],
	anchor_id: int,
	max_frames: int = 180
) -> void:
	for _frame: int in range(max_frames):
		var all_targeted := true
		for enemy: BoardingEnemy in enemies:
			if enemy.get_selected_anchor_id() != anchor_id:
				all_targeted = false
				break
		if all_targeted:
			return
		await physics_frame
	assert(false, "Ground enemies did not select the expected anchor")


func _wait_until_all_waiting(
	enemies: Array[BoardingEnemy],
	max_frames: int = 180
) -> void:
	for _frame: int in range(max_frames):
		var all_waiting := true
		for enemy: BoardingEnemy in enemies:
			if enemy.get_selected_anchor_id() >= 0 or not _is_waiting(enemy):
				all_waiting = false
				break
		if all_waiting:
			return
		await physics_frame
	assert(false, "Ground enemies did not reset to waiting without a path")


func _is_waiting(enemy: BoardingEnemy) -> bool:
	var saboteur := enemy.behavior as RecoveringRopeSaboteurBehavior
	if saboteur != null:
		return saboteur.state == RopeSaboteurBehavior.State.WAITING_WITHOUT_PATH
	return (
		enemy.controller.get_state()
		== BoardingEnemyController.State.WAITING_WITHOUT_PATH
	)


func _attach_anchor(
	anchors: AnchorSystem,
	paths: AnchorPathRegistry,
	anchor_id: int
) -> void:
	if not paths.is_path_available(anchor_id):
		anchors.toggle_anchor(anchor_id)
	await _wait_until_path_available(paths, anchor_id)


func _wait_until_path_available(
	paths: AnchorPathRegistry,
	anchor_id: int,
	max_frames: int = 360
) -> void:
	for _frame: int in range(max_frames):
		if paths.is_path_available(anchor_id):
			return
		await physics_frame
	assert(false, "Anchor path did not become available")


func _wait_until_path_closed(
	paths: AnchorPathRegistry,
	anchor_id: int,
	max_frames: int = 360
) -> void:
	for _frame: int in range(max_frames):
		if not paths.is_path_available(anchor_id):
			return
		await physics_frame
	assert(false, "Anchor path did not close")


func _wait_until_anchor_state(
	anchors: AnchorSystem,
	anchor_id: int,
	expected_state: int,
	max_frames: int = 360
) -> void:
	for _frame: int in range(max_frames):
		if anchors.get_anchor_state(anchor_id) == expected_state:
			return
		await physics_frame
	assert(false, "Anchor did not reach the expected state")


func _cleanup_enemies(enemies: Array[BoardingEnemy]) -> void:
	for enemy: BoardingEnemy in enemies:
		if is_instance_valid(enemy) and enemy.health.is_alive():
			enemy.kill(&"test_cleanup")


func _disable_automatic_spawners(game: Node) -> void:
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


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await physics_frame
