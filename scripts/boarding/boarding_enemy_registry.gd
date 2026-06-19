class_name BoardingEnemyRegistry
extends Node

signal enemy_registered(enemy_id: int, enemy: BoardingEnemy)
signal enemy_removed(enemy_id: int, reason: StringName)

var _enemies: Dictionary[int, BoardingEnemy] = {}
var _next_enemy_id: int = 0


func register_enemy(enemy: BoardingEnemy) -> int:
	var enemy_id: int = _next_enemy_id
	_next_enemy_id += 1
	_enemies[enemy_id] = enemy
	enemy.set_enemy_id(enemy_id)
	enemy.died.connect(_on_enemy_died)
	enemy_registered.emit(enemy_id, enemy)
	return enemy_id


func get_enemy(enemy_id: int) -> BoardingEnemy:
	return _enemies.get(enemy_id)


func get_all_enemies() -> Array[BoardingEnemy]:
	var result: Array[BoardingEnemy] = []
	var ids: Array[int] = _enemies.keys()
	ids.sort()
	for enemy_id: int in ids:
		var enemy: BoardingEnemy = _enemies[enemy_id]
		if is_instance_valid(enemy):
			result.append(enemy)
	return result


func get_active_count() -> int:
	return get_all_enemies().size()


func get_boarded_enemies() -> Array[BoardingEnemy]:
	var result: Array[BoardingEnemy] = []
	for enemy: BoardingEnemy in get_all_enemies():
		if enemy.is_on_platform() and enemy.health.is_alive():
			result.append(enemy)
	return result


func get_nearest_boarded_enemy(
	world_position: Vector2,
	max_distance: float = INF
) -> BoardingEnemy:
	var nearest: BoardingEnemy = null
	var nearest_distance_squared: float = max_distance * max_distance
	for enemy: BoardingEnemy in get_boarded_enemies():
		var distance_squared: float = world_position.distance_squared_to(
			enemy.global_position
		)
		if distance_squared < nearest_distance_squared:
			nearest = enemy
			nearest_distance_squared = distance_squared
	return nearest


func get_state_summary() -> String:
	var ground_count: int = 0
	var climbing_count: int = 0
	var boarded_count: int = 0
	for enemy: BoardingEnemy in get_all_enemies():
		var enemy_state: int = enemy.get_state()
		if (
			enemy_state == BoardingEnemyController.State.WAITING_WITHOUT_PATH
			or enemy_state == BoardingEnemyController.State.RUNNING_TO_ANCHOR
		):
			ground_count += 1
		elif enemy_state == BoardingEnemyController.State.CLIMBING:
			climbing_count += 1
		elif (
			enemy_state == BoardingEnemyController.State.ON_PLATFORM
			or enemy_state == BoardingEnemyController.State.FIGHTING
		):
			boarded_count += 1
	return "земля %d | трос %d | борт %d" % [
		ground_count,
		climbing_count,
		boarded_count,
	]


func _on_enemy_died(enemy_id: int, reason: StringName) -> void:
	if not _enemies.has(enemy_id):
		return
	_enemies.erase(enemy_id)
	enemy_removed.emit(enemy_id, reason)
