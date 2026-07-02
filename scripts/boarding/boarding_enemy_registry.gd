class_name BoardingEnemyRegistry
extends Node

signal enemy_registered(enemy_id: int, enemy: BoardingEnemy)
signal enemy_removed(enemy_id: int, reason: StringName)

var _enemies: Dictionary[int, BoardingEnemy] = {}
var _active_enemies: Array[BoardingEnemy] = []
var _pending_damage_by_enemy: Dictionary[int, Dictionary] = {}
var _next_enemy_id: int = 0
var _cache_generation: int = 0


func register_enemy(enemy: BoardingEnemy) -> int:
	var enemy_id: int = _next_enemy_id
	_next_enemy_id += 1
	_enemies[enemy_id] = enemy
	_active_enemies.append(enemy)
	_cache_generation += 1
	enemy.set_enemy_id(enemy_id)
	enemy.died.connect(_on_enemy_died)
	enemy_registered.emit(enemy_id, enemy)
	return enemy_id


func get_enemy(enemy_id: int) -> BoardingEnemy:
	return _enemies.get(enemy_id)


func get_all_enemies() -> Array[BoardingEnemy]:
	_prune_invalid_enemies()
	return _active_enemies.duplicate()


func get_active_enemies_view() -> Array[BoardingEnemy]:
	_prune_invalid_enemies()
	return _active_enemies


func get_cache_generation() -> int:
	return _cache_generation


func get_active_count() -> int:
	_prune_invalid_enemies()
	return _active_enemies.size()


func get_ground_count() -> int:
	var count: int = 0
	for enemy: BoardingEnemy in get_active_enemies_view():
		if enemy.is_counted_as_ground():
			count += 1
	return count


func get_climbing_count() -> int:
	var count: int = 0
	for enemy: BoardingEnemy in get_active_enemies_view():
		if enemy.is_counted_as_climbing():
			count += 1
	return count


func get_boarded_count() -> int:
	return get_boarded_enemies().size()


func get_boarded_enemies() -> Array[BoardingEnemy]:
	var result: Array[BoardingEnemy] = []
	for enemy: BoardingEnemy in get_active_enemies_view():
		if enemy.is_counted_as_boarded() and enemy.health.is_alive():
			result.append(enemy)
	return result


func reserve_pending_damage(
	enemy_id: int,
	source_id: StringName,
	amount: int
) -> bool:
	var enemy: BoardingEnemy = get_enemy(enemy_id)
	if enemy == null or not enemy.health.is_alive():
		return false
	if source_id == &"" or amount <= 0:
		return false
	var reservations: Dictionary = _pending_damage_by_enemy.get(enemy_id, {})
	reservations[source_id] = int(reservations.get(source_id, 0)) + amount
	_pending_damage_by_enemy[enemy_id] = reservations
	return true


func consume_pending_damage(
	enemy_id: int,
	source_id: StringName,
	amount: int
) -> void:
	if amount <= 0 or not _pending_damage_by_enemy.has(enemy_id):
		return
	var reservations: Dictionary = _pending_damage_by_enemy[enemy_id]
	var remaining: int = maxi(0, int(reservations.get(source_id, 0)) - amount)
	if remaining > 0:
		reservations[source_id] = remaining
	else:
		reservations.erase(source_id)
	_store_reservations(enemy_id, reservations)


func release_pending_damage(enemy_id: int, source_id: StringName) -> void:
	if not _pending_damage_by_enemy.has(enemy_id):
		return
	var reservations: Dictionary = _pending_damage_by_enemy[enemy_id]
	reservations.erase(source_id)
	_store_reservations(enemy_id, reservations)


func get_pending_damage(enemy_id: int) -> int:
	if not _pending_damage_by_enemy.has(enemy_id):
		return 0
	var result: int = 0
	var reservations: Dictionary = _pending_damage_by_enemy[enemy_id]
	for amount: Variant in reservations.values():
		result += maxi(0, int(amount))
	return result


func get_unreserved_health(enemy_id: int) -> int:
	var enemy: BoardingEnemy = get_enemy(enemy_id)
	if enemy == null or not enemy.health.is_alive():
		return 0
	return maxi(0, enemy.health.current_health - get_pending_damage(enemy_id))


func kill_climbing_on_anchor(
	anchor_id: int,
	reason: StringName = &"anchor_path_closed"
) -> int:
	var victims: Array[BoardingEnemy] = []
	for enemy: BoardingEnemy in get_active_enemies_view():
		if not enemy.health.is_alive():
			continue
		if not enemy.is_counted_as_climbing():
			continue
		if enemy.get_selected_anchor_id() != anchor_id:
			continue
		victims.append(enemy)
	for enemy: BoardingEnemy in victims:
		enemy.kill(reason)
	return victims.size()


func get_turret_targets() -> Array[BoardingEnemy]:
	var result: Array[BoardingEnemy] = []
	for enemy: BoardingEnemy in get_active_enemies_view():
		if enemy.is_targetable_by_turret():
			result.append(enemy)
	return result


func get_archetype_count(archetype_id: StringName) -> int:
	var count: int = 0
	for enemy: BoardingEnemy in get_active_enemies_view():
		if enemy.get_archetype_id() == archetype_id:
			count += 1
	return count


func get_archetype_summary() -> String:
	var counts: Dictionary[StringName, int] = {}
	var names: Dictionary[StringName, String] = {}
	for enemy: BoardingEnemy in get_active_enemies_view():
		var archetype_id: StringName = enemy.get_archetype_id()
		if archetype_id == &"":
			continue
		var previous_count: int = counts.get(archetype_id, 0)
		counts[archetype_id] = previous_count + 1
		names[archetype_id] = enemy.get_archetype_name()
	if counts.is_empty():
		return "НЕТ"
	var ids: Array[StringName] = counts.keys()
	ids.sort()
	var parts := PackedStringArray()
	for archetype_id: StringName in ids:
		parts.append("%s %d" % [names[archetype_id], counts[archetype_id]])
	return " | ".join(parts)


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
	return "земля %d | трос %d | борт %d | типы: %s" % [
		get_ground_count(),
		get_climbing_count(),
		get_boarded_count(),
		get_archetype_summary(),
	]


func _store_reservations(enemy_id: int, reservations: Dictionary) -> void:
	if reservations.is_empty():
		_pending_damage_by_enemy.erase(enemy_id)
	else:
		_pending_damage_by_enemy[enemy_id] = reservations


func _on_enemy_died(enemy_id: int, reason: StringName) -> void:
	if not _enemies.has(enemy_id):
		return
	var enemy: BoardingEnemy = _enemies[enemy_id]
	_pending_damage_by_enemy.erase(enemy_id)
	_enemies.erase(enemy_id)
	_remove_active_enemy(enemy)
	enemy_removed.emit(enemy_id, reason)


func _remove_active_enemy(enemy: BoardingEnemy) -> void:
	var index: int = _active_enemies.find(enemy)
	if index < 0:
		return
	_active_enemies.remove_at(index)
	_cache_generation += 1


func _prune_invalid_enemies() -> void:
	var changed: bool = false
	var index: int = _active_enemies.size() - 1
	while index >= 0:
		var enemy: BoardingEnemy = _active_enemies[index]
		if not is_instance_valid(enemy):
			_active_enemies.remove_at(index)
			changed = true
		index -= 1
	if changed:
		_cache_generation += 1
