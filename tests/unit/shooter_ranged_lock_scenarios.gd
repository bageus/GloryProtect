extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_locked_target()
	_test_dead_target_before_launch_returns_ready()
	print("Shooter ranged lock scenarios passed")
	quit()

func _test_locked_target() -> void:
	var owner := Node2D.new()
	root.add_child(owner)
	var first := _target(Vector2(100, 0), 3)
	var second := _target(Vector2(20, 0), 3)
	var ranged := _ranged(owner)
	assert(ranged.try_start(first))
	(second.get_parent() as Node2D).global_position = Vector2(5, 0)
	ranged.tick(0.1)
	ranged.tick(0.1)
	assert(first.current_health == 2)
	assert(second.current_health == 3)
	owner.queue_free()
	first.get_parent().queue_free()
	second.get_parent().queue_free()
	ranged.queue_free()

func _test_dead_target_before_launch_returns_ready() -> void:
	var owner := Node2D.new()
	root.add_child(owner)
	var first := _target(Vector2(100, 0), 1)
	var second := _target(Vector2(20, 0), 3)
	var ranged := _ranged(owner)
	assert(ranged.try_start(first))
	first.apply_damage(1)
	ranged.tick(0.1)
	assert(first.current_health == 0)
	assert(second.current_health == 3)
	assert(ranged.phase == RangedAttackComponent.Phase.READY)
	assert(ranged.remaining_time == 0.0)
	assert(ranged.try_start(second))
	owner.queue_free()
	first.get_parent().queue_free()
	second.get_parent().queue_free()
	ranged.queue_free()

func _ranged(owner: Node2D) -> RangedAttackComponent:
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
	return ranged

func _target(position: Vector2, points: int) -> HealthComponent:
	var node := Node2D.new()
	node.global_position = position
	root.add_child(node)
	var health := HealthComponent.new()
	node.add_child(health)
	health.configure(points)
	return health
