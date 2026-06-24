extends SceneTree


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	_test_controller_primes_first_attack_profile()
	_test_empty_sequence_does_not_advance_volley_counter()
	_test_three_locked_shots_before_cooldown()
	_test_sequence_stops_when_locked_target_dies()
	print("Shooter ranged sequence scenarios passed")
	quit()


func _test_controller_primes_first_attack_profile() -> void:
	var defender := Defender.new()
	var flow := GameFlowController.new()
	var roles := CrewRoleManager.new()
	var enemies := BoardingEnemyRegistry.new()
	var crew := CrewManager.new()
	var ranged := RangedAttackComponent.new()
	var controller := ShooterCombatController.new()
	controller.configure(
		defender,
		flow,
		roles,
		enemies,
		crew,
		ranged
	)
	assert(ranged.can_start())
	controller.free()
	ranged.free()
	crew.free()
	enemies.free()
	roles.free()
	flow.free()
	defender.free()


func _test_empty_sequence_does_not_advance_volley_counter() -> void:
	var defender := Defender.new()
	var flow := GameFlowController.new()
	var roles := CrewRoleManager.new()
	var enemies := BoardingEnemyRegistry.new()
	var crew := CrewManager.new()
	var ranged := RangedAttackComponent.new()
	var controller := ShooterCombatController.new()
	controller.configure(
		defender,
		flow,
		roles,
		enemies,
		crew,
		ranged
	)
	controller._on_attack_finished()
	assert(controller.get_completed_volley_count() == 0)
	controller._current_volley_hit_count = 1
	controller._on_attack_finished()
	assert(controller.get_completed_volley_count() == 1)
	controller.free()
	ranged.free()
	crew.free()
	enemies.free()
	roles.free()
	flow.free()
	defender.free()


func _test_three_locked_shots_before_cooldown() -> void:
	var owner := Node2D.new()
	root.add_child(owner)
	var target: HealthComponent = _make_target(Vector2(10.0, 0.0), 5)
	var ranged := _make_ranged(owner)
	var counters: Array[int] = [0, 0]
	ranged.attack_landed.connect(func(
		_target: HealthComponent,
		_damage: int
	) -> void:
		counters[0] += 1
	)
	ranged.attack_finished.connect(func() -> void:
		counters[1] += 1
	)
	assert(ranged.try_start_sequence(target, 3))
	for _index: int in range(6):
		ranged.tick(0.1)
	assert(target.current_health == 2)
	assert(counters[0] == 3)
	assert(counters[1] == 1)
	assert(ranged.phase == RangedAttackComponent.Phase.COOLDOWN)
	owner.queue_free()
	target.get_parent().queue_free()
	ranged.queue_free()


func _test_sequence_stops_when_locked_target_dies() -> void:
	var owner := Node2D.new()
	root.add_child(owner)
	var target: HealthComponent = _make_target(Vector2(10.0, 0.0), 1)
	var ranged := _make_ranged(owner)
	var landed_count: Array[int] = [0]
	ranged.attack_landed.connect(func(
		_target: HealthComponent,
		_damage: int
	) -> void:
		landed_count[0] += 1
	)
	assert(ranged.try_start_sequence(target, 3))
	ranged.tick(0.1)
	ranged.tick(0.1)
	assert(target.current_health == 0)
	assert(landed_count[0] == 1)
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


func _make_target(
	position: Vector2,
	health_points: int
) -> HealthComponent:
	var target := Node2D.new()
	target.global_position = position
	root.add_child(target)
	var health := HealthComponent.new()
	target.add_child(health)
	health.configure(health_points)
	return health
