class_name FlyingEnemyBehavior
extends EnemyBehaviorComponent

enum State {
	FLYING,
	LANDING,
	BOARDED,
	ATTACKING,
}

var state: int = State.FLYING
var profile: FlyingEnemyProfile
var platform: PlatformController
var crew: CrewManager
var registry: BoardingEnemyRegistry
var melee: MeleeAttackComponent


func setup(
	flying_profile: FlyingEnemyProfile,
	platform_controller: PlatformController,
	crew_manager: CrewManager,
	enemy_registry: BoardingEnemyRegistry,
	attack_component: MeleeAttackComponent
) -> void:
	assert(flying_profile != null and flying_profile.is_valid())
	profile = flying_profile
	platform = platform_controller
	crew = crew_manager
	registry = enemy_registry
	melee = attack_component
	target_domain = TargetDomain.AIR
	turret_targetable = true
	counts_as_ground = false
	counts_as_climbing = false
	counts_as_boarded = false


func _on_configured() -> void:
	assert(profile != null, "FlyingEnemyBehavior requires profile")
	assert(platform != null, "FlyingEnemyBehavior requires platform")
	assert(crew != null, "FlyingEnemyBehavior requires crew")
	assert(registry != null, "FlyingEnemyBehavior requires registry")
	assert(melee != null, "FlyingEnemyBehavior requires melee")
	state = State.FLYING
	_set_air_domain()
	publish_visual_state(&"flying")


func _on_stopped() -> void:
	melee.cancel()


func _tick_behavior(delta: float) -> void:
	melee.tick(delta)
	var target: Defender = crew.get_nearest_living_defender(enemy.global_position)
	if target == null:
		return
	match state:
		State.FLYING:
			_tick_flying(delta, target)
		State.LANDING:
			_tick_landing(delta, target)
		State.BOARDED, State.ATTACKING:
			_tick_boarded(delta, target)


func is_landed() -> bool:
	return state == State.BOARDED or state == State.ATTACKING


func _tick_flying(delta: float, target: Defender) -> void:
	var approach_position := Vector2(
		target.global_position.x,
		platform.global_position.y - profile.hover_height
	)
	var distance: float = enemy.global_position.distance_to(approach_position)
	if distance <= profile.attack_range:
		_set_state(State.LANDING)
		return
	var direction: Vector2 = enemy.global_position.direction_to(approach_position)
	var velocity: Vector2 = direction * profile.flight_speed
	velocity += _get_separation_velocity()
	enemy.global_position += velocity * delta


func _tick_landing(delta: float, target: Defender) -> void:
	var landing_position := _get_landing_position(target)
	var distance: float = enemy.global_position.distance_to(landing_position)
	var step: float = profile.flight_speed * delta
	if distance <= maxf(3.0, step):
		enemy.global_position = landing_position
		_complete_landing()
		return
	enemy.global_position = enemy.global_position.move_toward(
		landing_position,
		step
	)


func _tick_boarded(delta: float, target: Defender) -> void:
	enemy.global_position.y = target.global_position.y
	var horizontal_distance: float = absf(
		target.global_position.x - enemy.global_position.x
	)
	if horizontal_distance <= profile.attack_range:
		_set_state(State.ATTACKING)
		melee.try_start(target.health)
		return
	_set_state(State.BOARDED)
	var direction: float = signf(
		target.global_position.x - enemy.global_position.x
	)
	enemy.global_position.x += direction * profile.flight_speed * delta


func _get_landing_position(target: Defender) -> Vector2:
	var half_width: float = platform.get_platform_width() * 0.5
	var body_margin: float = maxf(4.0, enemy.get_body_radius())
	var minimum_x: float = platform.global_position.x - half_width + body_margin
	var maximum_x: float = platform.global_position.x + half_width - body_margin
	return Vector2(
		clampf(target.global_position.x, minimum_x, maximum_x),
		target.global_position.y
	)


func _complete_landing() -> void:
	target_domain = TargetDomain.GROUND
	counts_as_ground = false
	counts_as_climbing = false
	counts_as_boarded = true
	_set_state(State.BOARDED)


func _set_air_domain() -> void:
	target_domain = TargetDomain.AIR
	counts_as_ground = false
	counts_as_climbing = false
	counts_as_boarded = false


func _set_state(new_state: int) -> void:
	if state == new_state:
		return
	state = new_state
	match state:
		State.FLYING:
			publish_visual_state(&"flying")
		State.LANDING:
			publish_visual_state(&"landing")
		State.BOARDED:
			publish_visual_state(&"boarded")
		State.ATTACKING:
			publish_visual_state(&"attacking")


func _get_separation_velocity() -> Vector2:
	var result := Vector2.ZERO
	for other: BoardingEnemy in registry.get_all_enemies():
		if other == enemy or other.behavior == null:
			continue
		if not (other.behavior is FlyingEnemyBehavior):
			continue
		var other_flying := other.behavior as FlyingEnemyBehavior
		if other_flying.state != State.FLYING:
			continue
		var offset: Vector2 = enemy.global_position - other.global_position
		var distance: float = offset.length()
		if distance <= 0.001 or distance >= profile.separation_distance:
			continue
		var strength: float = 1.0 - distance / profile.separation_distance
		result += offset.normalized() * profile.separation_force * strength
	return result
