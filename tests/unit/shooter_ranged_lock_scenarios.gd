extends SceneTree


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	_test_begun_shot_keeps_original_target()
	_test_dead_locked_target_does_not_retarget()
	print("Shooter ranged lock scenarios passed")
	quit()


func _test_begun_shot_keeps_original_target() -> void:
	var owner := Node2D.new()
	owner.global_position = Vector2.ZERO
	root.add_child(owner)
	var first: HealthComponent = _make_target(Vector2(100.0, 0.0), 3)
	var second: HealthComponent = _make_target(Vector2(20.0, 0.0), 3)
	var ranged := RangedAttackComponent.new()
	root.add_child(ranged)
	var flow := GameFlowController.new()
	root.add_child(flow)
	var profile := RangedAttackProfile.new()
	profile.damage = 1
	profile.windup_duration = 0.1
	profile.cooldown_duration = 0.2
	profile.projectile_speed = 1000.0
	profile.maximum_range = 200.0
	ranged.configure(profile, owner, flow)
	assert(ranged.try_start(first))
	var second_node: Node2D = second.get_parent() as Node2D
	second_node.global_position = Vector2(5.0, 0.0)
	ranged.tick(0.1)
	ranged.tick(0.1)
	assert(first.current_health == 2)
	assert(second.current_health == 3)
	owner.queue_free()
	first.get_parent().queue_free()
	second.get_parent().queue_free()
	ranged.queue_free()
	flow.queue_free()


func _test_dead_locked_target_does_not_retarget() -> void:
	var owner := Node2D.new()
	owner.global_position = Vector2.ZERO
	root.add_child(owner)
	var first: HealthComponent = _make_target(Vector2(100.0, 0.0), 1)
	var second: HealthComponent = _make_target(Vector2(20.0, 0.0), 3)
	var ranged := RangedAttackComponent.new()
	root.add_child(ranged)
	var flow := GameFlowController.new()
	root.add_child(flow)
	var profile := RangedAttackProfile.new()
	profile.damage = 1
	profile.windup_duration = 0.1
	profile.cooldown_duration = 0.2
	profile.projectile_speed = 1000.0
	profile.maximum_range = 200.0
	ranged.configure(profile, owner, flow)
	assert(ranged.try_start(first))
	first.apply_damage(1)
	ranged.tick(0.1)
	ranged.tick(0.1)
	assert(first.current_health == 0)
	assert(second.current_health == 3)
	assert(ranged.phase == RangedAttackComponent.Phase.COOLDOWN)
	owner.queue_free()
	first.get_parent().queue_free()
	second.get_parent().queue_free()
	ranged.queue_free()
	flow.queue_free()


func _make_target(position: Vector2, health_points: int) -> HealthComponent:
	var target := Node2D.new()
	target.global_position = position
	root.add_child(target)
	var health := HealthComponent.new()
	target.add_child(health)
	health.configure(health_points)
	return health
