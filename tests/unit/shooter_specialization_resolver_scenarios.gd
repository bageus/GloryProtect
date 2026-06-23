extends SceneTree

const ENEMY_SCENE := preload("res://scenes/boarding/boarding_enemy.tscn")
const BALANCE: ShooterSpecializationBalance = preload(
	"res://resources/balance/shooter_specialization_balance.tres"
)
const POLICY: ShooterTargetPolicy = preload(
	"res://resources/crew/shooter_target_policy_default.tres"
)


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	await _test_piercing_and_explosion()
	await _test_air_mark_selects_strongest_target()
	await _test_anchor_knockdown_uses_common_death_flow()
	print("Shooter specialization resolver scenarios passed")
	quit()


func _test_piercing_and_explosion() -> void:
	var registry := BoardingEnemyRegistry.new()
	root.add_child(registry)
	var shooter := Defender.new()
	shooter.position = Vector2.ZERO
	var primary: BoardingEnemy = await _make_enemy(
		registry,
		Vector2(50.0, 0.0),
		5,
		BoardingEnemyController.State.ON_PLATFORM
	)
	var behind_one: BoardingEnemy = await _make_enemy(
		registry,
		Vector2(80.0, 0.0),
		5,
		BoardingEnemyController.State.ON_PLATFORM
	)
	var behind_two: BoardingEnemy = await _make_enemy(
		registry,
		Vector2(110.0, 0.0),
		5,
		BoardingEnemyController.State.ON_PLATFORM
	)
	var outside_lane: BoardingEnemy = await _make_enemy(
		registry,
		Vector2(90.0, 80.0),
		5,
		BoardingEnemyController.State.ON_PLATFORM
	)
	var outside_range: BoardingEnemy = await _make_enemy(
		registry,
		Vector2(250.0, 0.0),
		5,
		BoardingEnemyController.State.ON_PLATFORM
	)
	var upgrades := ShooterUpgradeRuntime.new()
	upgrades.apply_flag(&"shooter_specialization_sniper")
	upgrades.apply_flag(&"shooter_sniper_multi_pierce")
	upgrades.apply_flag(&"shooter_sniper_explosive_fifth")
	var resolver := ShooterCombatResolver.new()
	resolver.configure(BALANCE)
	resolver.resolve_bolt_hit(
		shooter,
		primary,
		registry,
		POLICY,
		upgrades,
		1,
		5,
		150.0
	)
	assert(behind_one.health.current_health == 3)
	assert(behind_two.health.current_health == 3)
	assert(outside_lane.health.current_health == 5)
	assert(outside_range.health.current_health == 5)
	shooter.free()
	registry.queue_free()


func _test_air_mark_selects_strongest_target() -> void:
	var registry := BoardingEnemyRegistry.new()
	root.add_child(registry)
	var shooter := Defender.new()
	var primary: BoardingEnemy = await _make_air_enemy(
		registry,
		Vector2(20.0, 0.0),
		2
	)
	var strongest: BoardingEnemy = await _make_air_enemy(
		registry,
		Vector2(40.0, 0.0),
		6
	)
	var weaker: BoardingEnemy = await _make_air_enemy(
		registry,
		Vector2(60.0, 0.0),
		3
	)
	var upgrades := ShooterUpgradeRuntime.new()
	upgrades.apply_flag(&"shooter_specialization_air_hunter")
	upgrades.apply_flag(&"shooter_air_mark_fifth")
	var resolver := ShooterCombatResolver.new()
	resolver.configure(BALANCE)
	resolver.resolve_bolt_hit(
		shooter,
		primary,
		registry,
		POLICY,
		upgrades,
		1,
		5,
		200.0
	)
	assert(strongest.is_damage_marked())
	assert(not weaker.is_damage_marked())
	assert(is_equal_approx(
		strongest.health.get_incoming_damage_multiplier(),
		BALANCE.mark_damage_multiplier
	))
	shooter.free()
	registry.queue_free()


func _test_anchor_knockdown_uses_common_death_flow() -> void:
	var registry := BoardingEnemyRegistry.new()
	root.add_child(registry)
	var climbing: BoardingEnemy = await _make_enemy(
		registry,
		Vector2(30.0, 0.0),
		5,
		BoardingEnemyController.State.CLIMBING
	)
	var removed_reason: StringName = &""
	registry.enemy_removed.connect(func(
		_enemy_id: int,
		reason: StringName
	) -> void:
		removed_reason = reason
	)
	var upgrades := ShooterUpgradeRuntime.new()
	upgrades.apply_flag(&"shooter_specialization_anchor_hunter")
	upgrades.apply_flag(&"shooter_anchor_knockdown_fifth")
	var resolver := ShooterCombatResolver.new()
	resolver.configure(BALANCE)
	assert(resolver.resolve_volley_finished(climbing, upgrades, 5))
	assert(removed_reason == &"shooter_anchor_knockdown")
	assert(registry.get_enemy(climbing.enemy_id) == null)
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
