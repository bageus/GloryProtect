class_name BoardingEnemyController
extends Node

enum State {
	WAITING_WITHOUT_PATH,
	RUNNING_TO_ANCHOR,
	CLIMBING,
	ON_PLATFORM,
	FIGHTING,
	JUMPING,
	DEAD,
}

var state: int = State.WAITING_WITHOUT_PATH
var selected_anchor_id: int = -1

var _configured: bool = false
var _climb_progress: float = 0.0
var _platform_local_x: float = 0.0
var _jump_elapsed: float = 0.0
var _jump_plan: BoardingJumpPlan = null
var _enemy: BoardingEnemy
var _balance: BoardingBalance
var _game_flow: GameFlowController
var _platform: PlatformController
var _paths: AnchorPathRegistry
var _crew: CrewManager
var _orbs: GroundOrbRegistry
var _movement_resolver: BoardingMovementResolver
var _jump_planner: BoardingJumpPlanner
var _melee: MeleeAttackComponent


func configure(
	enemy: BoardingEnemy,
	balance: BoardingBalance,
	game_flow: GameFlowController,
	platform: PlatformController,
	paths: AnchorPathRegistry,
	crew: CrewManager,
	orbs: GroundOrbRegistry,
	movement_resolver: BoardingMovementResolver,
	jump_planner: BoardingJumpPlanner,
	melee: MeleeAttackComponent
) -> void:
	_enemy = enemy
	_balance = balance
	_game_flow = game_flow
	_platform = platform
	_paths = paths
	_crew = crew
	_orbs = orbs
	_movement_resolver = movement_resolver
	_jump_planner = jump_planner
	_melee = melee
	_configured = true
	state = State.WAITING_WITHOUT_PATH
	_set_ground_height()


func _physics_process(delta: float) -> void:
	if not _configured or state == State.DEAD:
		return
	if not _game_flow.is_world_simulation_active():
		return

	_melee.tick(delta)
	match state:
		State.WAITING_WITHOUT_PATH:
			_update_waiting(delta)
		State.RUNNING_TO_ANCHOR:
			_update_running_to_anchor(delta)
		State.CLIMBING:
			_update_climbing(delta)
		State.ON_PLATFORM, State.FIGHTING:
			_update_on_platform(delta)
		State.JUMPING:
			_update_jumping(delta)


func stop() -> void:
	state = State.DEAD
	selected_anchor_id = -1
	_jump_plan = null
	_configured = false


func get_state() -> int:
	return state


func get_selected_anchor_id() -> int:
	return selected_anchor_id


func get_climb_progress() -> float:
	return _climb_progress


func get_platform_local_x() -> float:
	return _platform_local_x


func get_platform_occupancy_x() -> float:
	if state == State.JUMPING and _jump_plan != null:
		return _jump_plan.landing_x
	return _platform_local_x


func is_on_platform() -> bool:
	return (
		state == State.ON_PLATFORM
		or state == State.FIGHTING
		or state == State.JUMPING
	)


func force_board_at(local_x: float) -> void:
	selected_anchor_id = -1
	_climb_progress = 1.0
	_jump_plan = null
	_platform_local_x = _movement_resolver.find_nearest_platform_slot(
		_enemy,
		local_x
	)
	state = State.ON_PLATFORM
	_update_world_position_from_platform()


func _update_waiting(delta: float) -> void:
	var path: AnchorPathSnapshot = _paths.choose_nearest_path(
		_enemy.global_position.x
	)
	if path != null:
		selected_anchor_id = path.anchor_id
		state = State.RUNNING_TO_ANCHOR
		return

	var desired_x: float = move_toward(
		_enemy.global_position.x,
		_platform.global_position.x,
		_balance.ground_move_speed * delta
	)
	_enemy.global_position.x = _movement_resolver.resolve_ground_x(
		_enemy,
		_enemy.global_position.x,
		desired_x
	)
	_set_ground_height()


func _update_running_to_anchor(delta: float) -> void:
	if not _paths.is_path_available(selected_anchor_id):
		selected_anchor_id = -1
		state = State.WAITING_WITHOUT_PATH
		return

	var path: AnchorPathSnapshot = _paths.get_path(selected_anchor_id)
	if path == null:
		selected_anchor_id = -1
		state = State.WAITING_WITHOUT_PATH
		return

	var desired_x: float = move_toward(
		_enemy.global_position.x,
		path.ground_point.x,
		_balance.ground_move_speed * delta
	)
	_enemy.global_position.x = _movement_resolver.resolve_ground_x(
		_enemy,
		_enemy.global_position.x,
		desired_x
	)
	_set_ground_height()

	if (
		absf(_enemy.global_position.x - path.ground_point.x)
		> _balance.ground_arrival_epsilon
	):
		return

	var rope_length: float = maxf(
		1.0,
		path.ground_point.distance_to(path.platform_point)
	)
	if not _movement_resolver.can_enter_climb(
		_enemy,
		selected_anchor_id,
		rope_length
	):
		return

	_enemy.global_position = path.ground_point
	_climb_progress = 0.0
	state = State.CLIMBING


func _update_climbing(delta: float) -> void:
	if not _paths.is_path_available(selected_anchor_id):
		_enemy.kill(&"anchor_path_closed")
		return

	var path: AnchorPathSnapshot = _paths.get_path(selected_anchor_id)
	if path == null:
		_enemy.kill(&"anchor_path_closed")
		return

	var rope_length: float = maxf(
		1.0,
		path.ground_point.distance_to(path.platform_point)
	)
	var desired_progress: float = minf(
		1.0,
		_climb_progress + _balance.climb_move_speed * delta / rope_length
	)
	_climb_progress = _movement_resolver.resolve_climb_progress(
		_enemy,
		selected_anchor_id,
		_climb_progress,
		desired_progress,
		rope_length
	)
	_enemy.global_position = path.ground_point.lerp(
		path.platform_point,
		_climb_progress
	)

	if _climb_progress < 1.0:
		return

	var entry_local_x: float = (
		path.platform_point.x - _platform.global_position.x
	)
	if not _movement_resolver.can_exit_to_platform(_enemy, entry_local_x):
		return

	_platform_local_x = entry_local_x
	state = State.ON_PLATFORM
	_update_world_position_from_platform()


func _update_on_platform(delta: float) -> void:
	_update_world_position_from_platform()
	if _melee.is_attacking():
		state = State.FIGHTING
		return

	var target: Defender = _crew.get_nearest_living_defender(
		_enemy.global_position
	)
	if target == null:
		state = State.ON_PLATFORM
		return

	var target_local_x: float = (
		target.global_position.x - _platform.global_position.x
	)
	var distance: float = absf(target_local_x - _platform_local_x)
	if distance <= _balance.enemy_attack_range:
		if _melee.try_start(target.health):
			state = State.FIGHTING
		return

	var desired_x: float = move_toward(
		_platform_local_x,
		target_local_x,
		_balance.platform_move_speed * delta
	)
	var resolved_x: float = _movement_resolver.resolve_enemy_platform_x(
		_enemy,
		_platform_local_x,
		desired_x
	)
	if (
		absf(resolved_x - _platform_local_x) <= 0.01
		and absf(desired_x - _platform_local_x) > 0.01
	):
		var plan: BoardingJumpPlan = _jump_planner.create_plan(_enemy, target)
		if plan != null:
			_begin_jump(plan)
			return

	_platform_local_x = resolved_x
	state = State.ON_PLATFORM
	_update_world_position_from_platform()


func _begin_jump(plan: BoardingJumpPlan) -> void:
	_jump_plan = plan
	_jump_elapsed = 0.0
	state = State.JUMPING
	_update_world_position_from_platform()


func _update_jumping(delta: float) -> void:
	if _jump_plan == null:
		state = State.ON_PLATFORM
		_update_world_position_from_platform()
		return

	_jump_elapsed = minf(
		_jump_plan.duration,
		_jump_elapsed + delta
	)
	var progress: float = _jump_elapsed / _jump_plan.duration
	_platform_local_x = lerpf(
		_jump_plan.start_x,
		_jump_plan.landing_x,
		progress
	)
	var vertical_offset: float = -sin(progress * PI) * _jump_plan.height
	_update_world_position_from_platform(vertical_offset)

	if progress < 1.0:
		return

	_platform_local_x = _jump_plan.landing_x
	_jump_plan = null
	state = State.ON_PLATFORM
	_update_world_position_from_platform()
	_update_on_platform(0.0)


func _set_ground_height() -> void:
	_enemy.global_position.y = (
		_orbs.catalog.ground_y - _balance.ground_vertical_offset
	)


func _update_world_position_from_platform(
	vertical_offset: float = 0.0
) -> void:
	_enemy.global_position = _platform.global_position + Vector2(
		_platform_local_x,
		_balance.platform_local_y + vertical_offset
	)
