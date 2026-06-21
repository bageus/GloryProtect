extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")
const BALANCE: TurretUpgradeBalance = preload(
	"res://resources/balance/turret_upgrade_balance.tres"
)


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	await process_frame
	await process_frame

	var turrets: TurretUpgradeSystem = game.get_node("World/TurretSystem")
	var upgrades: UpgradeSystem = game.get_node("UpgradeSystem")
	assert(turrets != null)
	assert(upgrades.catalog.resource_path.ends_with("game_upgrade_catalog.tres"))
	_test_live_domain_effects(turrets, upgrades)
	await _test_piercing_hits_every_enemy_on_line(game)
	await _test_chain_and_pause_safe_stun(game, flow)
	print("Turret upgrade integration scenarios passed")
	quit()


func _test_live_domain_effects(
	turrets: TurretUpgradeSystem,
	upgrades: UpgradeSystem
) -> void:
	var catalog: UpgradeCatalog = upgrades.catalog
	assert(turrets.get_current_damage() == 1)
	assert(turrets.apply_upgrade_effect(
		catalog.get_definition(&"turret_damage_basic").effect
	))
	assert(turrets.apply_upgrade_effect(
		catalog.get_definition(&"turret_damage_advanced").effect
	))
	assert(turrets.get_current_damage() == 3)
	assert(turrets.apply_upgrade_effect(
		catalog.get_definition(&"turret_cooldown_basic").effect
	))
	assert(turrets.apply_upgrade_effect(
		catalog.get_definition(&"turret_cooldown_advanced").effect
	))
	assert(is_equal_approx(turrets.get_current_cooldown(), 0.8 * 0.7))
	assert(turrets.apply_upgrade_effect(
		catalog.get_definition(&"turret_range_basic").effect
	))
	assert(turrets.apply_upgrade_effect(
		catalog.get_definition(&"turret_range_advanced").effect
	))
	assert(is_equal_approx(turrets.get_current_range(), 360.0 * 1.4))


func _test_piercing_hits_every_enemy_on_line(game: Node) -> void:
	var spawn: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	var registry: BoardingEnemyRegistry = game.get_node("World/BoardingEnemyRegistry")
	var primary: BoardingEnemy = spawn.spawn_debug_on_platform(0.0, &"basic")
	var second: BoardingEnemy = spawn.spawn_debug_on_platform(48.0, &"basic")
	var third: BoardingEnemy = spawn.spawn_debug_on_platform(96.0, &"basic")
	var origin := Vector2(primary.global_position.x - 120.0, primary.global_position.y)
	var runtime := TurretUpgradeRuntime.new()
	assert(runtime.apply_flag(TurretUpgradeRuntime.HEAVY))
	assert(runtime.apply_flag(&"turret_heavy_piercing"))
	var resolver := TurretCombatResolver.new()
	resolver.configure(BALANCE, 10)
	assert(resolver.resolve_shot(
		primary,
		origin,
		500.0,
		registry,
		runtime,
		1
	) == 3)
	assert(not primary.health.is_alive())
	assert(not second.health.is_alive())
	assert(not third.health.is_alive())
	await process_frame


func _test_chain_and_pause_safe_stun(
	game: Node,
	flow: GameFlowController
) -> void:
	var spawn: BoardingSpawnDirector = game.get_node("World/BoardingSpawnDirector")
	var registry: BoardingEnemyRegistry = game.get_node("World/BoardingEnemyRegistry")
	var primary: BoardingEnemy = spawn.spawn_debug_on_platform(0.0, &"brute")
	var second: BoardingEnemy = spawn.spawn_debug_on_platform(30.0, &"brute")
	var third: BoardingEnemy = spawn.spawn_debug_on_platform(120.0, &"brute")
	var origin := Vector2(primary.global_position.x - 120.0, primary.global_position.y)
	var runtime := TurretUpgradeRuntime.new()
	assert(runtime.apply_flag(TurretUpgradeRuntime.ELECTRIC))
	assert(runtime.apply_flag(&"turret_electric_chain"))
	var resolver := TurretCombatResolver.new()
	resolver.configure(BALANCE, 22)
	assert(resolver.resolve_shot(
		primary,
		origin,
		500.0,
		registry,
		runtime,
		1
	) == 2)
	assert(primary.health.current_health == 2)
	assert(second.health.current_health == 2)
	assert(third.health.current_health == 3)
	assert(primary.is_stunned())
	assert(second.is_stunned())
	var paused_remaining: float = primary.get_stun_remaining()
	flow.toggle_manual_pause()
	await create_timer(0.05, true).timeout
	assert(is_equal_approx(primary.get_stun_remaining(), paused_remaining))
	flow.toggle_manual_pause()
	await create_timer(0.05, true).timeout
	assert(primary.get_stun_remaining() < paused_remaining)
