extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var game_flow: GameFlowController = game.get_node("GameFlowController")
	var difficulty: RunDifficulty = game.get_node("RunDifficulty")
	var waves: StrategicWaveSystem = game.get_node(
		"World/StrategicWaveSystem"
	)
	var mutations: StrategicGroupMutationController = game.get_node(
		"World/StrategicGroupMutationController"
	)
	var director: StrategicWaveDirector = game.get_node(
		"World/StrategicWaveDirector"
	)

	game_flow.state = GameFlowController.RunState.RUNNING
	difficulty.set_debug_elapsed_seconds(600.0)
	director.balance.first_wave_delay = 999.0
	director.balance.initial_wave_interval = 999.0
	director.balance.minimum_wave_interval = 999.0
	director.reset_for_run()
	waves.balance.mutation_cooldown = 0.0
	waves.balance.mutation_check_interval = 999.0
	waves.balance.merge_angle_tolerance = 0.5
	waves.balance.merge_distance_tolerance = 0.5
	waves.balance.minimum_split_enemy_count = 2
	waves.balance.maximum_split_parts = 3
	waves.balance.initial_split_chance = 1.0
	waves.balance.maximum_split_chance = 1.0
	waves.balance.split_redirect_chance = 1.0
	waves.balance.split_min_progress = 0.0
	waves.balance.split_max_progress = 1.0
	mutations.reset_for_run()
	mutations.set_debug_seed(2026)

	var first_id: int = waves.add_group(0, 5, 10.0, 0.0)
	var second_id: int = waves.add_group(0, 7, 10.0, 0.0)
	assert(first_id >= 0)
	assert(second_id >= 0)
	assert(waves.get_active_group_count() == 2)
	assert(waves.get_total_enemy_count() == 12)

	assert(mutations.run_mutation_check_now())
	assert(waves.get_active_group_count() == 1)
	assert(waves.get_total_enemy_count() == 12)
	var merged: StrategicGroupSnapshot = waves.get_group_snapshots()[0]
	assert(merged.enemy_count == 12)
	var split_angle: float = merged.map_angle
	var split_distance: float = merged.map_distance
	var original_section: int = merged.section_id

	waves.balance.merge_angle_tolerance = 0.0
	waves.balance.merge_distance_tolerance = 0.0
	assert(mutations.run_mutation_check_now())
	var split_groups: Array[StrategicGroupSnapshot] = waves.get_group_snapshots()
	assert(split_groups.size() >= 2)
	assert(split_groups.size() <= 3)
	assert(waves.get_total_enemy_count() == 12)

	var redirected_count: int = 0
	var counted_enemies: int = 0
	for snapshot: StrategicGroupSnapshot in split_groups:
		counted_enemies += snapshot.enemy_count
		assert(is_equal_approx(snapshot.map_angle, split_angle))
		assert(is_equal_approx(snapshot.map_distance, split_distance))
		if snapshot.section_id != original_section:
			redirected_count += 1
	assert(counted_enemies == 12)
	assert(redirected_count >= 1)

	var initial_positions: Dictionary = {}
	for snapshot: StrategicGroupSnapshot in split_groups:
		initial_positions[snapshot.group_id] = Vector2(
			snapshot.map_angle,
			snapshot.map_distance
		)
	await _wait_physics_frames(3)
	for snapshot: StrategicGroupSnapshot in waves.get_group_snapshots():
		var initial: Vector2 = initial_positions[snapshot.group_id]
		assert(snapshot.map_distance <= initial.y)
		assert(absf(snapshot.map_angle - initial.x) < 0.5)

	var check_before_pause: float = mutations.get_check_remaining()
	game_flow.begin_card_selection()
	assert(paused)
	await _wait_physics_frames(5)
	assert(is_equal_approx(mutations.get_check_remaining(), check_before_pause))
	game_flow.finish_card_selection()
	assert(not paused)

	print("Strategic group mutation scenarios passed")
	quit()


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await physics_frame
