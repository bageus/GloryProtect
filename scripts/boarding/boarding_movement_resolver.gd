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
		var other_state: int = other.get_state()
		if not _is_ground_state(other_state):
			continue
		resolved_x = _clamp_step_against_obstacle(
			current_x,
			resolved_x,
			other.global_position.x,
			boarding_balance.ground_enemy_spacing
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
	for step_index: int in range(1, boarding_balance.max_ground_enemies + 2):
		var candidate_x: float = (
			preferred_x
			+ direction
			* float(step_index)
			* boarding_balance.ground_enemy_spacing
		)
		if _is_ground_slot_free(enemy, candidate_x):
			return candidate_x
	return preferred_x


func can_enter_climb(
	enemy: BoardingEnemy,
	anchor_id: int,
	rope_length: float
) -> bool:
	var minimum_progress: float = INF
	for other: BoardingEnemy in _enemies.get_all_enemies():
		if other == enemy or not other.health.is_alive():
			continue
		if other.get_state() != BoardingEnemyController.State.CLIMBING:
			continue
		if other.controller.get_selected_anchor_id() != anchor_id:
			continue
		minimum_progress = minf(
			minimum_progress,
			other.controller.get_climb_progress()
		)
	if minimum_progress == INF:
		return true
	return (
		minimum_progress * maxf(1.0, rope_length)
		>= boarding_balance.climb_enemy_spacing
	)


func resolve_climb_progress(
	enemy: BoardingEnemy,
	anchor_id: int,
	current_progress: float,
	desired_progress: float,
	rope_length: float
) -> float:
	var nearest_ahead: float = INF
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
		nearest_ahead = minf(nearest_ahead, other_progress)

	if nearest_ahead == INF:
		return desired_progress

	var progress_gap: float = (
		boarding_balance.climb_enemy_spacing / maxf(1.0, rope_length)
	)
	var maximum_progress: float = maxf(
		current_progress,
		nearest_ahead - progress_gap
	)
	return minf(desired_progress, maximum_progress)


func can_exit_to_platform(enemy: BoardingEnemy, local_x: float) -> bool:
	return can_place_enemy_at(enemy, local_x)


func find_nearest_platform_slot(
	enemy: BoardingEnemy,
	preferred_x: float
) -> float:
	if can_place_enemy_at(enemy, preferred_x):
		return preferred_x

	var platform_half_width: float = _platform.get_platform_width() * 0.5
	var step_size: float = boarding_balance.platform_enemy_spacing
	var max_steps: int = ceili(platform_half_width * 2.0 / step_size)
	for step_index: int in range(1, max_steps + 1):
		var offset: float = float(step_index) * step_size
		var left_candidate: float = preferred_x - offset
		if can_place_enemy_at(enemy, left_candidate):
			return left_candidate
		var right_candidate: float = preferred_x + offset
		if can_place_enemy_at(enemy, right_candidate):
			return right_candidate
	return preferred_x


func find_nearest_defender_slot(preferred_x: float) -> float:
	if _is_defender_slot_free(preferred_x):
		return _clamp_defender_to_platform(preferred_x)

	var platform_half_width: float = _platform.get_platform_width() * 0.5
	var step_size: float = _get_enemy_defender_gap()
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
	var enemy_radius: float = boarding_balance.enemy_body_radius
	if local_x < -platform_half_width + enemy_radius:
		return false
	if local_x > platform_half_width - enemy_radius:
		return false

	for other: BoardingEnemy in _enemies.get_boarded_enemies():
		if other == enemy:
			continue
		if (
			absf(other.controller.get_platform_local_x() - local_x)
			< boarding_balance.platform_enemy_spacing
		):
			return false

	var defender_gap: float = _get_enemy_defender_gap()
	for defender: Defender in _crew.get_living_defenders():
		if absf(defender.position.x - local_x) < defender_gap:
			return false
	return true


func resolve_enemy_platform_x(
	enemy: BoardingEnemy,
	current_x: float,
	desired_x: float
) -> float:
	var resolved_x: float = _clamp_enemy_to_platform(desired_x)
	for other: BoardingEnemy in _enemies.get_boarded_enemies():
		if other == enemy:
			continue
		resolved_x = _clamp_step_against_obstacle(
			current_x,
			resolved_x,
			other.controller.get_platform_local_x(),
			boarding_balance.platform_enemy_spacing
		)

	var defender_gap: float = _get_enemy_defender_gap()
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
	var defender_gap: float = _get_enemy_defender_gap()
	for enemy: BoardingEnemy in _enemies.get_boarded_enemies():
		resolved_x = _clamp_step_against_obstacle(
			current_x,
			resolved_x,
			enemy.controller.get_platform_local_x(),
			defender_gap
		)
	return resolved_x


func _is_ground_slot_free(enemy: BoardingEnemy, world_x: float) -> bool:
	for other: BoardingEnemy in _enemies.get_all_enemies():
		if other == enemy or not other.health.is_alive():
			continue
		if not _is_ground_state(other.get_state()):
			continue
		if (
			absf(other.global_position.x - world_x)
			< boarding_balance.ground_enemy_spacing
		):
			return false
	return true


func _is_defender_slot_free(local_x: float) -> bool:
	var clamped_x: float = _clamp_defender_to_platform(local_x)
	if not is_equal_approx(local_x, clamped_x):
		return false
	var minimum_gap: float = _get_enemy_defender_gap()
	for enemy: BoardingEnemy in _enemies.get_boarded_enemies():
		if (
			absf(enemy.controller.get_platform_local_x() - local_x)
			< minimum_gap
		):
			return false
	return true


func _is_ground_state(enemy_state: int) -> bool:
	return (
		enemy_state == BoardingEnemyController.State.WAITING_WITHOUT_PATH
		or enemy_state == BoardingEnemyController.State.RUNNING_TO_ANCHOR
	)


func _clamp_enemy_to_platform(local_x: float) -> float:
	var half_width: float = _platform.get_platform_width() * 0.5
	return clampf(
		local_x,
		-half_width + boarding_balance.enemy_body_radius,
		half_width - boarding_balance.enemy_body_radius
	)


func _clamp_defender_to_platform(local_x: float) -> float:
	var half_width: float = _platform.get_platform_width() * 0.5
	return clampf(
		local_x,
		-half_width + crew_balance.defender_body_radius,
		half_width - crew_balance.defender_body_radius
	)


func _get_enemy_defender_gap() -> float:
	return (
		boarding_balance.enemy_body_radius
		+ crew_balance.defender_body_radius
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
