class_name RopeSaboteurController
extends BoardingEnemyBehavior

enum State {
	WAITING_WITHOUT_PATH,
	RUNNING_TO_ROPE,
	ARMING,
	DEAD,
}

var state: int = State.WAITING_WITHOUT_PATH
var selected_anchor_id: int = -1
var _arming_elapsed: float = 0.0
var _configured: bool = false
var _enemy: BoardingEnemy
var _archetype: RopeSaboteurArchetype
var _balance: BoardingBalance
var _game_flow: GameFlowController
var _platform: PlatformController
var _paths: AnchorPathRegistry
var _orbs: GroundOrbRegistry
var _movement_resolver: BoardingMovementResolver
var _anchors: AnchorSystem


func configure(
	enemy: BoardingEnemy,
	archetype: BoardingEnemyArchetype,
	balance: BoardingBalance,
	game_flow: GameFlowController,
	platform: PlatformController,
	paths: AnchorPathRegistry,
	_crew: CrewManager,
	orbs: GroundOrbRegistry,
	movement_resolver: BoardingMovementResolver,
	_jump_planner: BoardingJumpPlanner,
	_melee: MeleeAttackComponent,
	anchors: AnchorSystem
) -> void:
	assert(archetype is RopeSaboteurArchetype)
	_enemy = enemy
	_archetype = archetype as RopeSaboteurArchetype
	_balance = balance
	_game_flow = game_flow
	_platform = platform
	_paths = paths
	_orbs = orbs
	_movement_resolver = movement_resolver
	_anchors = anchors
	_configured = true
	state = State.WAITING_WITHOUT_PATH
	_set_ground_height()


func _physics_process(delta: float) -> void:
	if not _configured or state == State.DEAD:
		return
	if not _game_flow.is_world_simulation_active():
		return

	match state:
		State.WAITING_WITHOUT_PATH:
			_update_waiting(delta)
		State.RUNNING_TO_ROPE:
			_update_running(delta)
		State.ARMING:
			_update_arming(delta)


func stop() -> void:
	state = State.DEAD
	selected_anchor_id = -1
	_arming_elapsed = 0.0
	_configured = false


func get_state() -> int:
	return state


func get_selected_anchor_id() -> int:
	return selected_anchor_id


func is_grounded_for_limit() -> bool:
	return state != State.DEAD


func get_arming_progress() -> float:
	if _archetype == null or _archetype.arming_duration <= 0.0:
		return 0.0
	return clampf(_arming_elapsed / _archetype.arming_duration, 0.0, 1.0)


func is_arming() -> bool:
	return state == State.ARMING


func _update_waiting(delta: float) -> void:
	var path: AnchorPathSnapshot = _paths.choose_nearest_path(
		_enemy.global_position.x
	)
	if path != null:
		selected_anchor_id = path.anchor_id
		state = State.RUNNING_TO_ROPE
		return

	var desired_x: float = move_toward(
		_enemy.global_position.x,
		_platform.global_position.x,
		_archetype.ground_move_speed * delta
	)
	_enemy.global_position.x = _movement_resolver.resolve_ground_x(
		_enemy,
		_enemy.global_position.x,
		desired_x
	)
	_set_ground_height()


func _update_running(delta: float) -> void:
	var path: AnchorPathSnapshot = _get_selected_path_or_reset()
	if path == null:
		return

	var desired_x: float = move_toward(
		_enemy.global_position.x,
		path.ground_point.x,
		_archetype.ground_move_speed * delta
	)
	_enemy.global_position.x = _movement_resolver.resolve_ground_x(
		_enemy,
		_enemy.global_position.x,
		desired_x
	)
	_set_ground_height()

	if absf(_enemy.global_position.x - path.ground_point.x) > _balance.ground_arrival_epsilon:
		return
	_enemy.global_position = path.ground_point
	_arming_elapsed = 0.0
	state = State.ARMING


func _update_arming(delta: float) -> void:
	var path: AnchorPathSnapshot = _get_selected_path_or_reset()
	if path == null:
		return
	_enemy.global_position = path.ground_point
	_arming_elapsed = minf(
		_archetype.arming_duration,
		_arming_elapsed + delta
	)
	if _arming_elapsed < _archetype.arming_duration:
		return

	if _anchors.apply_rope_damage(
		selected_anchor_id,
		_archetype.rope_damage,
		&"rope_saboteur"
	):
		_enemy.kill(&"rope_sabotage")
		return
	_reset_target()


func _get_selected_path_or_reset() -> AnchorPathSnapshot:
	if not _paths.is_path_available(selected_anchor_id):
		_reset_target()
		return null
	var path: AnchorPathSnapshot = _paths.get_path(selected_anchor_id)
	if path == null:
		_reset_target()
	return path


func _reset_target() -> void:
	selected_anchor_id = -1
	_arming_elapsed = 0.0
	state = State.WAITING_WITHOUT_PATH


func _set_ground_height() -> void:
	_enemy.global_position.y = (
		_orbs.catalog.ground_y - _balance.ground_vertical_offset
	)
