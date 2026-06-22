extends SceneTree

const ENEMY_SCENE := preload("res://scenes/boarding/boarding_enemy.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	await _test_windup_and_projectile_freeze_during_pause()
	await _test_damage_mark_timer_freezes_during_pause()
	print("Shooter pause scenarios passed")
	quit()


func _test_windup_and_projectile_freeze_during_pause() -> void:
	var owner := Node2D.new()
	root.add_child(owner)
	var target_node := Node2D.new()
	target_node.global_position = Vector2(100.0, 0.0)
	root.add_child(target_node)
	var target := HealthComponent.new()
	target_node.add_child(target)
	target.configure(3)
	var flow := GameFlowController.new()
	flow.start_delay_seconds = 0.0
	root.add_child(flow)
	await process_frame
	var ranged := RangedAttackComponent.new()
	root.add_child(ranged)
	var profile := RangedAttackProfile.new()
	profile.damage = 1
	profile.windup_duration = 1.0
	profile.cooldown_duration = 1.0
	profile.projectile_speed = 100.0
	profile.maximum_range = 200.0
	ranged.configure(profile, owner, flow)
	assert(ranged.try_start(target))
	ranged._physics_process(0.4)
	assert(is_equal_approx(ranged.remaining_time, 0.6))
	flow.state = GameFlowController.RunState.MANUAL_PAUSE
	ranged._physics_process(1.0)
	assert(is_equal_approx(ranged.remaining_time, 0.6))
	flow.state = GameFlowController.RunState.RUNNING
	ranged._physics_process(0.6)
	assert(ranged.phase == RangedAttackComponent.Phase.PROJECTILE)
	var frozen_position: Vector2 = ranged.projectile_position
	flow.state = GameFlowController.RunState.CARD_SELECTION
	ranged._physics_process(1.0)
	assert(ranged.projectile_position == frozen_position)
	flow.state = GameFlowController.RunState.RUNNING
	ranged._physics_process(1.0)
	assert(target.current_health == 2)
	owner.queue_free()
	target_node.queue_free()
	ranged.queue_free()
	flow.queue_free()


func _test_damage_mark_timer_freezes_during_pause() -> void:
	var flow := GameFlowController.new()
	flow.start_delay_seconds = 0.0
	root.add_child(flow)
	await process_frame
	var enemy: BoardingEnemy = ENEMY_SCENE.instantiate() as BoardingEnemy
	root.add_child(enemy)
	await process_frame
	enemy._game_flow = flow
	enemy.health.configure(5)
	assert(enemy.apply_damage_mark(10.0, 1.5))
	enemy._physics_process(2.0)
	assert(is_equal_approx(enemy.get_damage_mark_remaining(), 8.0))
	flow.state = GameFlowController.RunState.MANUAL_PAUSE
	enemy._physics_process(5.0)
	assert(is_equal_approx(enemy.get_damage_mark_remaining(), 8.0))
	assert(is_equal_approx(enemy.health.get_incoming_damage_multiplier(), 1.5))
	flow.state = GameFlowController.RunState.RUNNING
	enemy._physics_process(8.0)
	assert(not enemy.is_damage_marked())
	assert(is_equal_approx(enemy.health.get_incoming_damage_multiplier(), 1.0))
	enemy.queue_free()
	flow.queue_free()
