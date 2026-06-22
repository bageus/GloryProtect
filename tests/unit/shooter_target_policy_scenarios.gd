extends SceneTree

const ENEMY_SCENE := preload("res://scenes/boarding/boarding_enemy.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	await _test_strongest_priority()
	await _test_air_priority()
	await _test_anchor_priority()
	print("Shooter target policy scenarios passed")
	quit()


func _test_strongest_priority() -> void:
	var registry := BoardingEnemyRegistry.new()
	root.add_child(registry)
	var near: BoardingEnemy = await _make_enemy(
		registry,
		Vector2(20.0, 0.0),
		2,
		BoardingEnemyController.State.ON_PLATFORM
	)
	var strong: BoardingEnemy = await _make_enemy(
		registry,
		Vector2(100.0, 0.0),
		6,
		BoardingEnemyController.State.ON_PLATFORM
	)
	var policy := ShooterTargetPolicy.new()
	policy.priority_mode = ShooterTargetPolicy.PriorityMode.STRONGEST
	var selector := ShooterTargetSelector.new()
	assert(selector.select_target(registry, Vector2.ZERO, 200.0, policy) == strong)
	assert(selector.select_target(registry, Vector2.ZERO, 40.0, policy) == near)
	registry.queue_free()


func _test_air_priority() -> void:
	var registry := BoardingEnemyRegistry.new()
	root.add_child(registry)
	var ground: BoardingEnemy = await _make_enemy(
		registry,
		Vector2(10.0, 0.0),
		5,
		BoardingEnemyController.State.ON_PLATFORM
	)
	var air: BoardingEnemy = await _make_air_enemy(
		registry,
		Vector2(100.0, 0.0),
		1
	)
	var policy := ShooterTargetPolicy.new()
	policy.priority_mode = ShooterTargetPolicy.PriorityMode.AIR_FIRST
	var selector := ShooterTargetSelector.new()
	assert(selector.select_target(registry, Vector2.ZERO, 200.0, policy) == air)
	policy.allow_air = false
	assert(selector.select_target(registry, Vector2.ZERO, 200.0, policy) == ground)
	registry.queue_free()


func _test_anchor_priority() -> void:
	var registry := BoardingEnemyRegistry.new()
	root.add_child(registry)
	var boarded: BoardingEnemy = await _make_enemy(
		registry,
		Vector2(10.0, 0.0),
		5,
		BoardingEnemyController.State.ON_PLATFORM
	)
	var climbing: BoardingEnemy = await _make_enemy(
		registry,
		Vector2(100.0, 0.0),
		1,
		BoardingEnemyController.State.CLIMBING
	)
	var policy := ShooterTargetPolicy.new()
	policy.priority_mode = ShooterTargetPolicy.PriorityMode.ANCHOR_FIRST
	var selector := ShooterTargetSelector.new()
	assert(selector.select_target(registry, Vector2.ZERO, 200.0, policy) == climbing)
	policy.allow_climbing = false
	assert(selector.select_target(registry, Vector2.ZERO, 200.0, policy) == boarded)
	registry.queue_free()


func _make_enemy(
	registry: BoardingEnemyRegistry,
	position: Vector2,
	health_points: int,
	state: int
) -> BoardingEnemy:
	var enemy: BoardingEnemy = ENEMY_SCENE.instantiate() as BoardingEnemy
	root.add_child(enemy)
	await process_frame
	enemy.global_position = position
	enemy.health.configure(health_points)
	enemy.controller.state = state
	registry.register_enemy(enemy)
	return enemy


func _make_air_enemy(
	registry: BoardingEnemyRegistry,
	position: Vector2,
	health_points: int
) -> BoardingEnemy:
	var enemy: BoardingEnemy = await _make_enemy(
		registry,
		position,
		health_points,
		BoardingEnemyController.State.WAITING_WITHOUT_PATH
	)
	var behavior := EnemyBehaviorComponent.new()
	behavior.target_domain = EnemyBehaviorComponent.TargetDomain.AIR
	behavior.active = true
	enemy.add_child(behavior)
	enemy.behavior = behavior
	return enemy
