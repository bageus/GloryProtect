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
	var economy: RunEconomy = game.get_node("RunEconomy")
	var shield: ShieldSystem = game.get_node("ShieldSystem")
	var recharge: ShieldRechargeController = game.get_node(
		"World/ShieldRechargeController"
	)
	var waves: StrategicWaveSystem = game.get_node(
		"World/StrategicWaveSystem"
	)
	var director: StrategicWaveDirector = game.get_node(
		"World/StrategicWaveDirector"
	)
	var minimap: Control = game.get_node("CanvasLayer/StrategicMinimap")
	recharge.set_physics_process(false)

	assert(minimap.visible)
	assert(game_flow.state == GameFlowController.RunState.START_DELAY)
	var delayed_remaining: float = director.get_wave_remaining()
	await _wait_physics_frames(5)
	assert(is_equal_approx(director.get_wave_remaining(), delayed_remaining))
	assert(waves.get_active_group_count() == 0)

	game_flow.state = GameFlowController.RunState.RUNNING
	difficulty.set_debug_elapsed_seconds(300.0)
	director.balance.initial_wave_size = 8
	director.balance.maximum_wave_size = 8
	director.balance.initial_target_sections = 2
	director.balance.maximum_target_sections = 2
	director.balance.initial_travel_duration = 0.2
	director.balance.minimum_travel_duration = 0.2
	director.balance.impact_interval = 0.03
	director.balance.damage_per_enemy = 1.0
	director.balance.initial_wave_interval = 999.0
	director.balance.minimum_wave_interval = 999.0
	director.set_debug_seed(12345)

	var shield_before: float = _get_total_shield_health(shield)
	assert(director.spawn_wave_now() == 8)
	assert(director.get_wave_number() == 1)
	assert(waves.get_active_group_count() == 2)
	assert(waves.get_total_enemy_count() == 8)

	var snapshots: Array[StrategicGroupSnapshot] = waves.get_group_snapshots()
	assert(snapshots.size() == 2)
	assert(snapshots[0].section_id != snapshots[1].section_id)
	for snapshot: StrategicGroupSnapshot in snapshots:
		assert(snapshot.section_id >= 0)
		assert(snapshot.section_id < shield.get_section_count())
		assert(snapshot.enemy_count > 0)

	await _wait_physics_frames(2)
	var progress_before_pause: float = (
		waves.get_group_snapshots()[0].progress
	)
	game_flow.begin_card_selection()
	assert(paused)
	await _wait_physics_frames(5)
	assert(is_equal_approx(
		waves.get_group_snapshots()[0].progress,
		progress_before_pause
	))
	game_flow.finish_card_selection()
	assert(not paused)

	await _wait_until_groups_empty(waves, 180)
	assert(waves.get_active_group_count() == 0)
	assert(waves.get_total_enemy_count() == 0)
	assert(is_equal_approx(
		_get_total_shield_health(shield),
		shield_before - 8.0
	))
	assert(economy.get_coins() == economy.balance.starting_coins)

	director.balance.initial_travel_duration = 10.0
	director.balance.minimum_travel_duration = 10.0
	assert(director.spawn_wave_now() == 8)
	assert(waves.get_active_group_count() == 2)
	game_flow.end_run(&"test_restart")
	game_flow.start_run()
	await process_frame
	assert(waves.get_active_group_count() == 0)
	assert(waves.get_total_enemy_count() == 0)
	assert(director.get_wave_number() == 0)
	assert(is_equal_approx(
		director.get_wave_remaining(),
		director.balance.first_wave_delay
	))

	print("Strategic wave scenarios passed")
	quit()


func _get_total_shield_health(shield: ShieldSystem) -> float:
	var total: float = 0.0
	for section_id: int in range(shield.get_section_count()):
		total += shield.get_health(section_id)
	return total


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await physics_frame


func _wait_until_groups_empty(
	waves: StrategicWaveSystem,
	max_frames: int
) -> void:
	for _frame: int in range(max_frames):
		if waves.get_active_group_count() == 0:
			return
		await physics_frame
	assert(false, "Strategic groups did not finish in time")
