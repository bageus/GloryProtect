class_name ShooterTargetPolicy
extends Resource

enum PriorityMode {
	NEAREST,
	STRONGEST,
	AIR_FIRST,
	ANCHOR_FIRST,
}

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
	if enemy.get_target_domain() == EnemyBehaviorComponent.TargetDomain.AIR:
		return allow_air
	if enemy.is_counted_as_climbing():
		return allow_climbing
	if enemy.is_counted_as_boarded():
		return allow_boarded
	if enemy.get_state() == BoardingEnemyController.State.JUMPING:
		return allow_jumping
	return false


func get_priority_score(enemy: BoardingEnemy, origin: Vector2) -> float:
	if not is_valid_target(enemy):
		return -INF
	match priority_mode:
		PriorityMode.STRONGEST:
			return float(enemy.health.current_health) * 10000.0 - origin.distance_squared_to(enemy.global_position)
		PriorityMode.AIR_FIRST:
			var air_bonus: float = 1000000.0 if enemy.get_target_domain() == EnemyBehaviorComponent.TargetDomain.AIR else 0.0
			return air_bonus - origin.distance_squared_to(enemy.global_position)
		PriorityMode.ANCHOR_FIRST:
			var anchor_bonus: float = 1000000.0 if enemy.is_counted_as_climbing() else 0.0
			return anchor_bonus - origin.distance_squared_to(enemy.global_position)
	return -origin.distance_squared_to(enemy.global_position)
