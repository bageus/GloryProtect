extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_reservation_accounting()
	_test_selectors_skip_fully_reserved_targets()
	print("Pending damage reservation scenarios passed")
	quit()


func _test_reservation_accounting() -> void:
	var registry := BoardingEnemyRegistry.new()
	var enemy := _enemy(Vector2.ZERO, 3)
	var enemy_id: int = registry.register_enemy(enemy)
	assert(registry.get_unreserved_health(enemy_id) == 3)
	assert(registry.reserve_pending_damage(enemy_id, &"source_a", 2))
	assert(registry.get_pending_damage(enemy_id) == 2)
	assert(registry.get_unreserved_health(enemy_id) == 1)
	assert(registry.reserve_pending_damage(enemy_id, &"source_b", 1))
	assert(registry.get_unreserved_health(enemy_id) == 0)
	registry.consume_pending_damage(enemy_id, &"source_a", 1)
	assert(registry.get_pending_damage(enemy_id) == 2)
	registry.release_pending_damage(enemy_id, &"source_b")
	assert(registry.get_unreserved_health(enemy_id) == 2)
	enemy.died.emit(enemy_id, &"test")
	assert(registry.get_pending_damage(enemy_id) == 0)
	assert(registry.get_enemy(enemy_id) == null)


func _test_selectors_skip_fully_reserved_targets() -> void:
	var registry := BoardingEnemyRegistry.new()
	var first := _enemy(Vector2(10, 0), 1)
	var second := _enemy(Vector2(20, 0), 2)
	registry.register_enemy(first)
	registry.register_enemy(second)
	var policy := ShooterTargetPolicy.new()
	policy.allow_boarded = true
	var shooter_selector := ShooterTargetSelector.new()
	var turret_selector := TurretTargetSelector.new()
	assert(shooter_selector.select_target(
		registry,
		Vector2.ZERO,
		100.0,
		policy
	) == first)
	assert(turret_selector.get_nearest_target(
		registry,
		Vector2.ZERO,
		100.0
	) == first)
	assert(registry.reserve_pending_damage(first.enemy_id, &"source_a", 1))
	assert(shooter_selector.select_target(
		registry,
		Vector2.ZERO,
		100.0,
		policy
	) == second)
	assert(turret_selector.get_nearest_target(
		registry,
		Vector2.ZERO,
		100.0
	) == second)
	registry.release_pending_damage(first.enemy_id, &"source_a")
	assert(shooter_selector.select_target(
		registry,
		Vector2.ZERO,
		100.0,
		policy
	) == first)


func _enemy(position: Vector2, health_points: int) -> BoardingEnemy:
	var enemy := BoardingEnemy.new()
	enemy.global_position = position
	var health := HealthComponent.new()
	health.configure(health_points)
	enemy.health = health
	var behavior := EnemyBehaviorComponent.new()
	behavior.active = true
	behavior.counts_as_boarded = true
	behavior.turret_targetable = true
	enemy.behavior = behavior
	return enemy
