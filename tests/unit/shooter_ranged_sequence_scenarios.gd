extends SceneTree


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	_test_three_locked_shots_before_cooldown()
	_test_sequence_stops_when_locked_target_dies()
	print("Shooter ranged sequence scenarios passed")
	quit()


func _test_three_locked_shots_before_cooldown() -> void:
	var owner := Node2D.new()
	root.add_child(owner)
	var target: HealthComponent = _make_target(Vector2(10.0, 0.0), 5)
	var ranged := _make_ranged(owner)
	var landed_count: int = 0
	var finished_count: int = 0
	ranged.attack_landed.connect(func(
		_target: HealthComponent,
		_damage: int
	) -> void:
		landed_count += 1
	)
	ranged.attack_finished.connect(func() -> void:
		finished_count += 1
	)
	assert(ranged.try_start_sequence(target, 3))
	for _index: int in range(6):
		ranged.tick(0.1)
	assert(target.current_health == 2)
	assert(landed_count == 3)
	assert(finished_count == 1)
	assert(ranged.phase == RangedAttackComponent.Phase.COOLDOWN)
	owner.queue_free()
	target.get_parent().queue_free()
	ranged.queue_free()


func _test_sequence_stops_when_locked_target_dies() -> void:
	var owner := Node2D.new()
	root.add_child(owner)
	var target: HealthComponent = _make_target(Vector2(10.0, 0.0), 1)
	var ranged := _make_ranged(owner)
	var landed_count: int = 0
	ranged.attack_landed.connect(func(
		_target: HealthComponent,
		_damage: int
	) -> void:
		landed_count += 1
	)
	assert(ranged.try_start_sequence(target, 3))
	ranged.tick(0.1)
	ranged.tick(0.1)
	assert(target.current_health == 0)
	assert(landed_count == 1)
	assert(ranged.phase == RangedAttackComponent.Phase.COOLDOWN)
	owner.queue_free()
	target.get_parent().queue_free()
	ranged.queue_free()


func _make_ranged(owner: Node2D) -> RangedAttackComponent:
	var ranged := RangedAttackComponent.new()
	root.add_child(ranged)
	var flow := GameFlowController.new()
	root.add_child(flow)
	var profile := RangedAttackProfile.new()
	profile.damage = 1
	profile.windup_duration = 0.1
	profile.cooldown_duration = 0.5
	profile.projectile_speed = 1000.0
	profile.maximum_range = 100.0
	ranged.configure(profile, owner, flow)
	return ranged


func _make_target(position: Vector2, health_points: int) -> HealthComponent:
	var target := Node2D.new()
	target.global_position = position
	root.add_child(target)
	var health := HealthComponent.new()
	target.add_child(health)
	health.configure(health_points)
	return health
