class_name ShooterTargetPolicy
extends Resource

enum PriorityMode {
	NEAREST,
	STRONGEST,
	AIR_FIRST,
	ANCHOR_FIRST,
}

const PRIORITY_TIER_SCORE: float = 1.0e12

@export var allow_boarded: bool = true
@export var allow_climbing: bool = true
@export var allow_air: bool = true
@export var allow_jumping: bool = true
@export var priority_mode: PriorityMode = PriorityMode.NEAREST


func is_valid_target(enemy: BoardingEnemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if not enemy.health.is_alive():
		return false
	if _get_target_domain(enemy) == EnemyBehaviorComponent.TargetDomain.AIR:
		return allow_air
	if enemy.is_counted_as_climbing():
		return allow_climbing
	if enemy.get_state() == BoardingEnemyController.State.JUMPING:
		return allow_jumping
	if enemy.is_counted_as_boarded():
		return allow_boarded
	return false


func get_priority_score(enemy: BoardingEnemy, origin: Vector2) -> float:
	if not is_valid_target(enemy):
		return -INF
	var distance_score: float = -origin.distance_squared_to(
		enemy.global_position
	)
	match priority_mode:
		PriorityMode.STRONGEST:
			return (
				float(enemy.health.current_health) * PRIORITY_TIER_SCORE
				+ distance_score
			)
		PriorityMode.AIR_FIRST:
			var air_bonus: float = 0.0
			if _get_target_domain(enemy) == EnemyBehaviorComponent.TargetDomain.AIR:
				air_bonus = PRIORITY_TIER_SCORE
			return air_bonus + distance_score
		PriorityMode.ANCHOR_FIRST:
			var anchor_bonus: float = 0.0
			if enemy.is_counted_as_climbing():
				anchor_bonus = PRIORITY_TIER_SCORE
			return anchor_bonus + distance_score
	return distance_score


func _get_target_domain(enemy: BoardingEnemy) -> int:
	if enemy.behavior != null:
		return enemy.behavior.target_domain
	return EnemyBehaviorComponent.TargetDomain.GROUND
