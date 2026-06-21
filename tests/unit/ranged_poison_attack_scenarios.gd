extends SceneTree

const RANGED_PROFILE := preload("res://resources/combat/ranged_attack_default.tres")
const POISON_PROFILE := preload("res://resources/combat/poison_default.tres")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	await _test_locked_ranged_target_and_pause()
	await _test_poison_damage_pause_and_death()
	print("Ranged and poison attack scenarios passed")
	quit()


func _test_locked_ranged_target_and_pause() -> void:
	var flow := GameFlowController.new()
	flow.name = "GameFlowController"
	root.add_child(flow)
	await process_frame
	flow.state = GameFlowController.RunState.RUNNING

	var shooter := Node2D.new()
	root.add_child(shooter)
	var first_target := _create_target(Vector2(120.0, 0.0), 3)
	var second_target := _create_target(Vector2(80.0, 0.0), 3)
	var attack := RangedAttackComponent.new()
	shooter.add_child(attack)
	attack.configure(RANGED_PROFILE, shooter, flow)
	assert(attack.try_start(first_target))
	assert(attack.locked_target == first_target)

	flow.state = GameFlowController.RunState.MANUAL_PAUSE
	var paused_phase: int = attack.phase
	var paused_time: float = attack.remaining_time
	await _wait_physics_frames(5)
	assert(attack.phase == paused_phase)
	assert(is_equal_approx(attack.remaining_time, paused_time))

	flow.state = GameFlowController.RunState.RUNNING
	await _wait_physics_frames(120)
	assert(first_target.current_health == 2)
	assert(second_target.current_health == 3)
	assert(attack.locked_target == first_target or attack.locked_target == null)

	shooter.queue_free()
	first_target.get_parent().queue_free()
	second_target.get_parent().queue_free()
	flow.queue_free()
	await process_frame


func _test_poison_damage_pause_and_death() -> void:
	var flow := GameFlowController.new()
	flow.name = "GameFlowController"
	root.add_child(flow)
	await process_frame
	flow.state = GameFlowController.RunState.RUNNING

	var target_node := Node2D.new()
	target_node.name = "PoisonTarget"
	root.add_child(target_node)
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	target_node.add_child(health)
	health.configure(2)
	var status := StatusEffectComponent.new()
	status.health_path = NodePath("../HealthComponent")
	status.game_flow_path = NodePath("../../GameFlowController")
	target_node.add_child(status)
	await process_frame

	assert(status.apply_poison(POISON_PROFILE))
	flow.state = GameFlowController.RunState.MANUAL_PAUSE
	await _wait_physics_frames(20)
	assert(health.current_health == 2)

	flow.state = GameFlowController.RunState.RUNNING
	await _wait_physics_frames(130)
	assert(health.current_health == 1)
	await _wait_physics_frames(130)
	assert(health.current_health == 0)
	assert(not status.is_poisoned())

	target_node.queue_free()
	flow.queue_free()
	await process_frame


func _create_target(position: Vector2, hit_points: int) -> HealthComponent:
	var node := Node2D.new()
	node.position = position
	root.add_child(node)
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	node.add_child(health)
	health.configure(hit_points)
	return health


func _wait_physics_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await physics_frame
