class_name BoardingEnemyBehavior
extends Node


func configure(
	enemy: BoardingEnemy,
	archetype: BoardingEnemyArchetype,
	balance: BoardingBalance,
	game_flow: GameFlowController,
	platform: PlatformController,
	paths: AnchorPathRegistry,
	crew: CrewManager,
	orbs: GroundOrbRegistry,
	movement_resolver: BoardingMovementResolver,
	jump_planner: BoardingJumpPlanner,
	melee: MeleeAttackComponent,
	anchors: AnchorSystem
) -> void:
	assert(enemy != null, "BoardingEnemyBehavior requires enemy")
	assert(archetype != null, "BoardingEnemyBehavior requires archetype")
	assert(balance != null, "BoardingEnemyBehavior requires balance")
	assert(game_flow != null, "BoardingEnemyBehavior requires game flow")
	assert(platform != null, "BoardingEnemyBehavior requires platform")
	assert(paths != null, "BoardingEnemyBehavior requires paths")
	assert(crew != null, "BoardingEnemyBehavior requires crew")
	assert(orbs != null, "BoardingEnemyBehavior requires orb registry")
	assert(movement_resolver != null, "BoardingEnemyBehavior requires movement")
	assert(jump_planner != null, "BoardingEnemyBehavior requires jump planner")
	assert(melee != null, "BoardingEnemyBehavior requires melee component")
	assert(anchors != null, "BoardingEnemyBehavior requires anchor system")


func stop() -> void:
	pass


func get_state() -> int:
	return -1


func get_selected_anchor_id() -> int:
	return -1


func get_climb_progress() -> float:
	return 0.0


func get_platform_local_x() -> float:
	return 0.0


func get_platform_occupancy_x() -> float:
	return get_platform_local_x()


func is_grounded_for_limit() -> bool:
	return false


func is_climbing() -> bool:
	return false


func is_on_platform() -> bool:
	return false


func is_fighting() -> bool:
	return false


func is_turret_targetable() -> bool:
	return is_climbing() or is_on_platform()


func force_board_at(_local_x: float) -> void:
	pass
