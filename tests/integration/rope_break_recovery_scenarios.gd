extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root.tscn")

var _recovery_anchor_ids: Array[int] = []
var _recovery_sources: Array[StringName] = []
var _recovery_removed_counts: Array[int] = []


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	await _test_destroyed_rope_closes_path_and_returns_anchor()
	await _test_destroyed_overloaded_rope_recovers_cleanly()
	await _test_natural_wind_break_removes_climbers()
	print("Rope break recovery scenarios passed")
	quit()


func _test_destroyed_rope_closes_path_and_returns_anchor() -> void:
	_clear_recovery_events()
	var game: Node = GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var game_flow: GameFlowController = game.get_node("GameFlowController")
	var economy: RunEconomy = game.get_node("RunEconomy")
	var wind: WindSystem = game.get_node("WindSystem")
	var platform: PlatformController = game.get_node("World/Platform")
	var anchors: AnchorSystem = game.get_node("World/AnchorSystem")
	var director: BoardingSpawnDirector = game.get_node(
		"World/BoardingSpawnDirector"
	)
	var registry: BoardingEnemyRegistry = game.get_node(
		"World/BoardingEnemyRegistry"
	)

	_disable_unrelated_world_systems(game, director)
	_configure_stable_world(game_flow, wind, platform)
	await _install_anchor(anchors, 2)
	anchors.anchor_recovery_started.connect(_on_anchor_recovery_started)

	var boarded: BoardingEnemy = director.spawn_debug_on_platform(0.0, &"basic")
	assert(boarded != null)
	boarded.controller.set_physics_process(false)
	var basic: BoardingEnemyArchetype = director.enemy_catalog.get_archetype(&"basic")
	var original_climb_speed: float = basic.climb_move_speed
	basic.climb_move_speed = 18.0

	var first: BoardingEnemy = director.spawn_debug_archetype(&"basic", 1)
	var second: BoardingEnemy = director.spawn_debug_archetype(&"basic", 1)
	assert(first != null and second != null)
	assert(await _wait_until(
		func() -> bool:
			return (
				first.is_counted_as_climbing()
				and second.is_counted_as_climbing()
			),
		600
	))

	var starting_coins: int = economy.get_coins()
	var target: AnchorRopeSnapshot = anchors.get_rope_snapshot(2)
	assert(target != null and not target.is_destroyed)
	assert(anchors.apply_rope_damage(
		2,
		target.maximum_durability,
		&"integration_break"
	))

	assert(not anchors.is_path_available(2))
	assert(anchors.get_anchor_state(2) == AnchorRuntime.State.RETURNING)
	assert(registry.get_climbing_count() == 0)
	assert(boarded.health.is_alive())
	assert(boarded.is_counted_as_boarded())
	assert(registry.get_enemy(boarded.enemy_id) == boarded)
	assert(economy.get_coins() == starting_coins + 2)
	assert(_recovery_anchor_ids == [2])
	assert(_recovery_sources == [&"integration_break"])
	assert(_recovery_removed_counts == [2])

	game_flow.state = GameFlowController.RunState.MANUAL_PAUSE
	await _wait_physics_frames(90)
	assert(anchors.get_anchor_state(2) == AnchorRuntime.State.RETURNING)
	game_flow.state = GameFlowController.RunState.RUNNING
	assert(await _wait_until(
		func() -> bool:
			return anchors.get_anchor_state(2) == AnchorRuntime.State.STOWED,
		180
	))

	await _install_anchor(anchors, 2)
	var restored: AnchorRopeSnapshot = anchors.get_rope_snapshot(2)
	assert(is_equal_approx(
		restored.current_durability,
		restored.maximum_durability
	))
	basic.climb_move_speed = original_climb_speed

	game.queue_free()
	await process_frame


func _test_destroyed_overloaded_rope_recovers_cleanly() -> void:
	_clear_recovery_events()
	var game: Node = GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var game_flow: GameFlowController = game.get_node("GameFlowController")
	var wind: WindSystem = game.get_node("WindSystem")
	var platform: PlatformController = game.get_node("World/Platform")
	var anchors: AnchorSystem = game.get_node("World/AnchorSystem")
	var director: BoardingSpawnDirector = game.get_node(
		"World/BoardingSpawnDirector"
	)

	_disable_unrelated_world_systems(game, director)
	_configure_stable_world(game_flow, wind, platform)
	await _install_anchor(anchors, 2)
	anchors.anchor_recovery_started.connect(_on_anchor_recovery_started)

	wind.set_debug_state(1, 3)
	platform.position.x = anchors.get_maximum_platform_x()
	assert(await _wait_until(
		func() -> bool:
			return anchors.get_anchor_state(2) == AnchorRuntime.State.OVERLOADED,
		60
	))

	var snapshot: AnchorRopeSnapshot = anchors.get_rope_snapshot(2)
	assert(anchors.apply_rope_damage(
		2,
		snapshot.maximum_durability,
		&"integration_overload_break"
	))
	assert(not anchors.is_path_available(2))
	assert(anchors.get_anchor_state(2) == AnchorRuntime.State.RETURNING)
	assert(_recovery_sources == [&"integration_overload_break"])
	assert(await _wait_until(
		func() -> bool:
			return anchors.get_anchor_state(2) == AnchorRuntime.State.STOWED,
		180
	))

	game.queue_free()
	await process_frame


func _test_natural_wind_break_removes_climbers() -> void:
	_clear_recovery_events()
	var game: Node = GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var game_flow: GameFlowController = game.get_node("GameFlowController")
	var economy: RunEconomy = game.get_node("RunEconomy")
	var wind: WindSystem = game.get_node("WindSystem")
	var platform: PlatformController = game.get_node("World/Platform")
	var anchors: AnchorSystem = game.get_node("World/AnchorSystem")
	var director: BoardingSpawnDirector = game.get_node(
		"World/BoardingSpawnDirector"
	)
	var registry: BoardingEnemyRegistry = game.get_node(
		"World/BoardingEnemyRegistry"
	)

	_disable_unrelated_world_systems(game, director)
	_configure_stable_world(game_flow, wind, platform)
	await _install_anchor(anchors, 2)
	anchors.anchor_recovery_started.connect(_on_anchor_recovery_started)

	var basic: BoardingEnemyArchetype = director.enemy_catalog.get_archetype(&"basic")
	var original_climb_speed: float = basic.climb_move_speed
	basic.climb_move_speed = 18.0
	var climber: BoardingEnemy = director.spawn_debug_archetype(&"basic", 1)
	assert(climber != null)
	var climber_id: int = climber.enemy_id
	assert(await _wait_until(
		func() -> bool: return climber.is_counted_as_climbing(),
		480
	))

	var starting_coins: int = economy.get_coins()
	wind.set_debug_state(1, 3)
	platform.position.x = anchors.get_maximum_platform_x()
	assert(await _wait_until(
		func() -> bool:
			return anchors.get_anchor_state(2) == AnchorRuntime.State.OVERLOADED,
		60
	))
	assert(await _wait_until(
		func() -> bool:
			return anchors.get_anchor_state(2) == AnchorRuntime.State.RETURNING,
		240
	))

	assert(not anchors.is_path_available(2))
	assert(registry.get_climbing_count() == 0)
	assert(registry.get_enemy(climber_id) == null)
	assert(economy.get_coins() == starting_coins + 1)
	assert(_recovery_anchor_ids == [2])
	assert(_recovery_sources == [&"wind_overload"])
	assert(_recovery_removed_counts == [1])
	assert(await _wait_until(
		func() -> bool:
			return anchors.get_anchor_state(2) == AnchorRuntime.State.STOWED,
		180
	))
	basic.climb_move_speed = original_climb_speed

	game.queue_free()
	await process_frame


func _disable_unrelated_world_systems(
	game: Node,
	director: BoardingSpawnDirector
) -> void:
	director.set_process(false)
	director.set_physics_process(false)
	var node_paths: Array[NodePath] = [
		NodePath("World/StrategicWaveSystem"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
		NodePath("World/CrewCombatCoordinator"),
		NodePath("World/TurretSystem"),
	]
	for node_path: NodePath in node_paths:
		var system: Node = game.get_node(node_path)
		system.set_process(false)
		system.set_physics_process(false)


func _configure_stable_world(
	game_flow: GameFlowController,
	wind: WindSystem,
	platform: PlatformController
) -> void:
	game_flow.state = GameFlowController.RunState.RUNNING
	wind.balance.level_forces = PackedFloat32Array([0.0, 0.0, 0.0])
	wind.balance.fluctuation_force = 0.0
	wind.set_debug_state(1, 1)
	platform.position.x = 0.0
	platform.horizontal_velocity = 0.0


func _install_anchor(anchors: AnchorSystem, anchor_id: int) -> void:
	anchors.toggle_anchor(anchor_id)
	assert(await _wait_until(
		func() -> bool: return anchors.is_path_available(anchor_id),
		240
	))


func _clear_recovery_events() -> void:
	_recovery_anchor_ids.clear()
	_recovery_sources.clear()
	_recovery_removed_counts.clear()


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame: int in range(maximum_frames):
		if predicate.call():
			return true
		await physics_frame
	return predicate.call()


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await physics_frame


func _on_anchor_recovery_started(
	anchor_id: int,
	source: StringName,
	removed_enemy_count: int
) -> void:
	_recovery_anchor_ids.append(anchor_id)
	_recovery_sources.append(source)
	_recovery_removed_counts.append(removed_enemy_count)
