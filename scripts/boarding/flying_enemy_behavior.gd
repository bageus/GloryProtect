class_name FlyingEnemyBehavior
extends EnemyBehaviorComponent

enum State {
	FLYING,
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
	publish_visual_state(&"flying")


func _on_stopped() -> void:
	melee.cancel()


func _tick_behavior(delta: float) -> void:
	melee.tick(delta)
	var target: Defender = crew.get_nearest_living_defender(enemy.global_position)
	if target == null:
		return
	var target_position := Vector2(
		target.global_position.x,
		platform.global_position.y - profile.hover_height
	)
	var distance: float = enemy.global_position.distance_to(target_position)
	if distance <= profile.attack_range:
		_set_state(State.ATTACKING)
		melee.try_start(target.health)
		return
	_set_state(State.FLYING)
	var direction: Vector2 = enemy.global_position.direction_to(target_position)
	var velocity: Vector2 = direction * profile.flight_speed
	velocity += _get_separation_velocity()
	enemy.global_position += velocity * delta


func _set_state(new_state: int) -> void:
	if state == new_state:
		return
	state = new_state
	if state == State.ATTACKING:
		publish_visual_state(&"attacking")
	else:
		publish_visual_state(&"flying")


func _get_separation_velocity() -> Vector2:
	var result := Vector2.ZERO
	for other: BoardingEnemy in registry.get_all_enemies():
		if other == enemy or other.behavior == null:
			continue
		if not (other.behavior is FlyingEnemyBehavior):
			continue
		var offset: Vector2 = enemy.global_position - other.global_position
		var distance: float = offset.length()
		if distance <= 0.001 or distance >= profile.separation_distance:
			continue
		var strength: float = 1.0 - distance / profile.separation_distance
		result += offset.normalized() * profile.separation_force * strength
	return result
