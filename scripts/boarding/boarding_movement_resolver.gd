class_name BoardingMovementResolver
extends Node

@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("CrewManager") var crew_manager_path: NodePath
@export_node_path("BoardingEnemyRegistry") var enemy_registry_path: NodePath
@export var boarding_balance: BoardingBalance
@export var crew_balance: CrewBalance

@onready var _platform: PlatformController = get_node(platform_path)
@onready var _crew: CrewManager = get_node(crew_manager_path)
@onready var _enemies: BoardingEnemyRegistry = get_node(enemy_registry_path)


func _ready() -> void:
	assert(
		boarding_balance != null,
		"BoardingMovementResolver requires BoardingBalance"
	)
	assert(
		crew_balance != null,
		"BoardingMovementResolver requires CrewBalance"
	)


func resolve_ground_x(
	enemy: BoardingEnemy,
	current_x: float,
	desired_x: float
) -> float:
	var resolved_x: float = desired_x
	for other: BoardingEnemy in _enemies.get_all_enemies():
		if other == enemy or not other.health.is_alive():
			continue
		if not other.is_counted_as_ground():
			continue
		resolved_x = _clamp_step_against_obstacle(
			current_x,
			resolved_x,
			other.global_position.x,
			get_enemy_gap(
				enemy,
				other,
				boarding_balance.ground_enemy_spacing
			)
		)
	return resolved_x


func find_ground_spawn_x(
	enemy: BoardingEnemy,
	preferred_x: float,
	spawn_side: int
) -> float:
	if _is_ground_slot_free(enemy, preferred_x):
		return preferred_x
	var direction: float = 1.0 if spawn_side >= 0 else -1.0
	var step_size: float = maxf(
		boarding_balance.ground_enemy_spacing,
		enemy.get_body_radius() * 2.0
	)
	for step_index: int in range(1, boarding_balance.max_ground_enemies + 2):
		var candidate_x: float = (
			preferred_x + direction * float(step_index) * step_size
		)
		if _is_ground_slot_free(enemy, candidate_x):
			return candidate_x
	return preferred_x


func can_enter_climb(
	enemy: BoardingEnemy,
	anchor_id: int,
	rope_length: float
) -> bool:
	for other: BoardingEnemy in _enemies.get_all_enemies():
		if other == enemy or not other.health.is_alive():
			continue
		if other.get_state() != BoardingEnemyController.State.CLIMBING:
			continue
		if other.controller.get_selected_anchor_id() != anchor_id:
			continue
		var distance_from_entry: float = (
			other.controller.get_climb_progress() * maxf(1.0, rope_length)
		)
		if distance_from_entry < get_enemy_gap(
			enemy,
			other,
			boarding_balance.climb_enemy_spacing
		):
			return false
	return true


func resolve_climb_progress(
	enemy: BoardingEnemy,
	anchor_id: int,
	current_progress: float,
	desired_progress: float,
	rope_length: float
) -> float:
	var resolved_progress: float = desired_progress
	var safe_rope_length: float = maxf(1.0, rope_length)
	for other: BoardingEnemy in _enemies.get_all_enemies():
		if other == enemy or not other.health.is_alive():
			continue
		if other.get_state() != BoardingEnemyController.State.CLIMBING:
			continue
		if other.controller.get_selected_anchor_id() != anchor_id:
			continue
		var other_progress: float = other.controller.get_climb_progress()
		if other_progress <= current_progress:
			continue
		var progress_gap: float = get_enemy_gap(
			enemy,
			other,
			boarding_balance.climb_enemy_spacing
		) / safe_rope_length
		var maximum_progress: float = maxf(
			current_progress,
			other_progress - progress_gap
		)
		resolved_progress = minf(resolved_progress, maximum_progress)
	return resolved_progress


func can_exit_to_platform(enemy: BoardingEnemy, local_x: float) -> bool:
	return can_place_enemy_at(enemy, local_x)


func find_nearest_platform_slot(
	enemy: BoardingEnemy,
	preferred_x: float
) -> float:
	if can_place_enemy_at(enemy, preferred_x):
		return preferred_x
	var platform_half_width: float = _platform.get_platform_width() * 0.5
	var step_size: float = maxf(
		boarding_balance.platform_enemy_spacing,
		enemy.get_body_radius() * 2.0
	)
	var max_steps: int = ceili(platform_half_width * 2.0 / step_size)
	for step_index: int in range(1, max_steps + 1):
		var offset: float = float(step_index) * step_size
		var left_candidate: float = preferred_x - offset
		if can_place_enemy_at(enemy, left_candidate):
			return left_candidate
		var right_candidate: float = preferred_x + offset
		if can_place_enemy_at(enemy, right_candidate):
			return right_candidate
	return _clamp_enemy_to_platform(enemy, preferred_x)


func find_nearest_defender_slot(preferred_x: float) -> float:
	if _is_defender_slot_free(preferred_x):
		return _clamp_defender_to_platform(preferred_x)

	var platform_half_width: float = _platform.get_platform_width() * 0.5
	var step_size: float = maxf(
		boarding_balance.platform_enemy_spacing,
		crew_balance.defender_body_radius * 2.0
	)
	var max_steps: int = ceili(platform_half_width * 2.0 / step_size)
	for step_index: int in range(1, max_steps + 1):
		var offset: float = float(step_index) * step_size
		var left_candidate: float = preferred_x - offset
		if _is_defender_slot_free(left_candidate):
			return _clamp_defender_to_platform(left_candidate)
		var right_candidate: float = preferred_x + offset
		if _is_defender_slot_free(right_candidate):
			return _clamp_defender_to_platform(right_candidate)
	return _clamp_defender_to_platform(preferred_x)


func can_place_enemy_at(enemy: BoardingEnemy, local_x: float) -> bool:
	var platform_half_width: float = _platform.get_platform_width() * 0.5
	var enemy_radius: float = enemy.get_body_radius()
	if local_x < -platform_half_width + enemy_radius:
		return false
	if local_x > platform_half_width - enemy_radius:
		return false

	for other: BoardingEnemy in _enemies.get_boarded_enemies():
		if other == enemy:
			continue
		if (
			absf(other.controller.get_platform_occupancy_x() - local_x)
			< get_enemy_gap(
				enemy,
				other,
				boarding_balance.platform_enemy_spacing
			)
		):
			return false

	var defender_gap: float = get_enemy_defender_gap(enemy)
	for defender: Defender in _crew.get_living_defenders():
		if absf(defender.position.x - local_x) < defender_gap:
			return false
	return true


func resolve_enemy_platform_x(
	enemy: BoardingEnemy,
	current_x: float,
	desired_x: float
) -> float:
	var resolved_x: float = _clamp_enemy_to_platform(enemy, desired_x)
	for other: BoardingEnemy in _enemies.get_boarded_enemies():
		if other == enemy:
			continue
		resolved_x = _clamp_step_against_obstacle(
			current_x,
			resolved_x,
			other.controller.get_platform_occupancy_x(),
			get_enemy_gap(
				enemy,
				other,
				boarding_balance.platform_enemy_spacing
			)
		)

	var defender_gap: float = get_enemy_defender_gap(enemy)
	for defender: Defender in _crew.get_living_defenders():
		resolved_x = _clamp_step_against_obstacle(
			current_x,
			resolved_x,
			defender.position.x,
			defender_gap
		)
	return resolved_x


func resolve_defender_platform_x(
	_defender: Defender,
	current_x: float,
	desired_x: float
) -> float:
	var resolved_x: float = _clamp_defender_to_platform(desired_x)
	for enemy: BoardingEnemy in _enemies.get_boarded_enemies():
		resolved_x = _clamp_step_against_obstacle(
			current_x,
			resolved_x,
			enemy.controller.get_platform_occupancy_x(),
			get_enemy_defender_gap(enemy)
		)
	return resolved_x


func get_enemy_gap(
	first: BoardingEnemy,
	second: BoardingEnemy,
	minimum_spacing: float
) -> float:
	return maxf(
		minimum_spacing,
		first.get_body_radius() + second.get_body_radius()
	)


func get_enemy_defender_gap(enemy: BoardingEnemy) -> float:
	return enemy.get_body_radius() + crew_balance.defender_body_radius


func _is_ground_slot_free(enemy: BoardingEnemy, world_x: float) -> bool:
	for other: BoardingEnemy in _enemies.get_all_enemies():
		if other == enemy or not other.health.is_alive():
			continue
		if not other.is_counted_as_ground():
			continue
		if (
			absf(other.global_position.x - world_x)
			< get_enemy_gap(
				enemy,
				other,
				boarding_balance.ground_enemy_spacing
			)
		):
			return false
	return true


func _is_defender_slot_free(local_x: float) -> bool:
	var clamped_x: float = _clamp_defender_to_platform(local_x)
	if not is_equal_approx(local_x, clamped_x):
		return false
	for enemy: BoardingEnemy in _enemies.get_boarded_enemies():
		if (
			absf(enemy.controller.get_platform_occupancy_x() - local_x)
			< get_enemy_defender_gap(enemy)
		):
			return false
	return true


func _clamp_enemy_to_platform(
	enemy: BoardingEnemy,
	local_x: float
) -> float:
	var half_width: float = _platform.get_platform_width() * 0.5
	var radius: float = enemy.get_body_radius()
	return clampf(local_x, -half_width + radius, half_width - radius)


func _clamp_defender_to_platform(local_x: float) -> float:
	var half_width: float = _platform.get_platform_width() * 0.5
	return clampf(
		local_x,
		-half_width + crew_balance.defender_body_radius,
		half_width - crew_balance.defender_body_radius
	)


func _clamp_step_against_obstacle(
	current_x: float,
	desired_x: float,
	obstacle_x: float,
	minimum_gap: float
) -> float:
	if desired_x > current_x and obstacle_x >= current_x:
		var right_limit: float = obstacle_x - minimum_gap
		if desired_x > right_limit:
			return maxf(current_x, right_limit)
	elif desired_x < current_x and obstacle_x <= current_x:
		var left_limit: float = obstacle_x + minimum_gap
		if desired_x < left_limit:
			return minf(current_x, left_limit)
	return desired_x
