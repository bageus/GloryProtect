class_name BoardingJumpPlanner
extends Node

@export_node_path("BoardingEnemyRegistry") var enemy_registry_path: NodePath
@export_node_path("BoardingMovementResolver") var movement_resolver_path: NodePath
@export var boarding_balance: BoardingBalance
@export var crew_balance: CrewBalance

@onready var _enemies: BoardingEnemyRegistry = get_node(enemy_registry_path)
@onready var _movement_resolver: BoardingMovementResolver = get_node(
	movement_resolver_path
)


func _ready() -> void:
	assert(boarding_balance != null, "BoardingJumpPlanner requires BoardingBalance")
	assert(crew_balance != null, "BoardingJumpPlanner requires CrewBalance")


func create_plan(
	enemy: BoardingEnemy,
	target: Defender
) -> BoardingJumpPlan:
	if enemy == null or target == null:
		return null
	if not enemy.health.is_alive() or not target.health.is_alive():
		return null
	if target.blocks_enemy_jump():
		return null
	if enemy.archetype == null:
		return null

	var current_x: float = enemy.controller.get_platform_local_x()
	var target_x: float = target.position.x
	var direction: float = signf(target_x - current_x)
	if is_zero_approx(direction):
		return null

	var blocker: BoardingEnemy = _find_front_blocker(
		enemy,
		current_x,
		target_x,
		direction
	)
	if blocker == null:
		return null

	var blocker_x: float = blocker.controller.get_platform_occupancy_x()
	var enemy_gap: float = _movement_resolver.get_enemy_gap(
		enemy,
		blocker,
		boarding_balance.platform_enemy_spacing
	)
	if (
		absf(blocker_x - current_x)
		> enemy_gap + boarding_balance.jump_trigger_tolerance
	):
		return null
	if (
		absf(target_x - blocker_x)
		> blocker.archetype.attack_range
			+ boarding_balance.jump_trigger_tolerance
	):
		return null

	var landing_gap: float = (
		enemy.get_body_radius()
		+ crew_balance.defender_body_radius
		+ boarding_balance.jump_landing_clearance
	)
	var landing_x: float = target_x + direction * landing_gap
	if (
		absf(landing_x - current_x)
		> boarding_balance.jump_max_horizontal_distance
	):
		return null
	if not _movement_resolver.can_place_enemy_at(enemy, landing_x):
		return null

	return BoardingJumpPlan.new(
		current_x,
		landing_x,
		boarding_balance.jump_duration,
		boarding_balance.jump_height
	)


func _find_front_blocker(
	enemy: BoardingEnemy,
	current_x: float,
	target_x: float,
	direction: float
) -> BoardingEnemy:
	var nearest: BoardingEnemy = null
	var nearest_distance: float = INF
	for other: BoardingEnemy in _enemies.get_boarded_enemies():
		if other == enemy or not other.health.is_alive():
			continue
		var other_state: int = other.get_state()
		if (
			other_state != BoardingEnemyController.State.ON_PLATFORM
			and other_state != BoardingEnemyController.State.FIGHTING
		):
			continue

		var other_x: float = other.controller.get_platform_occupancy_x()
		var from_enemy: float = (other_x - current_x) * direction
		var before_target: float = (target_x - other_x) * direction
		if from_enemy <= 0.0 or before_target <= 0.0:
			continue
		if from_enemy < nearest_distance:
			nearest = other
			nearest_distance = from_enemy
	return nearest
