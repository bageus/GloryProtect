class_name BoardingEnemyController
extends Node

enum State {
	WAITING_WITHOUT_PATH,
	RUNNING_TO_ANCHOR,
	CLIMBING,
	ON_PLATFORM,
	FIGHTING,
	DEAD,
}

var state: int = State.WAITING_WITHOUT_PATH
var selected_anchor_id: int = -1

var _configured: bool = false
var _climb_progress: float = 0.0
var _platform_local_x: float = 0.0
var _enemy: BoardingEnemy
var _balance: BoardingBalance
var _game_flow: GameFlowController
var _platform: PlatformController
var _paths: AnchorPathRegistry
var _crew: CrewManager
var _orbs: GroundOrbRegistry
var _melee: MeleeAttackComponent


func configure(
	enemy: BoardingEnemy,
	balance: BoardingBalance,
	game_flow: GameFlowController,
	platform: PlatformController,
	paths: AnchorPathRegistry,
	crew: CrewManager,
	orbs: GroundOrbRegistry,
	melee: MeleeAttackComponent
) -> void:
	_enemy = enemy
	_balance = balance
	_game_flow = game_flow
	_platform = platform
	_paths = paths
	_crew = crew
	_orbs = orbs
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


func stop() -> void:
	state = State.DEAD
	selected_anchor_id = -1
	_configured = false


func get_state() -> int:
	return state


func is_on_platform() -> bool:
	return state == State.ON_PLATFORM or state == State.FIGHTING


func force_board_at(local_x: float) -> void:
	selected_anchor_id = -1
	_climb_progress = 1.0
	_platform_local_x = local_x
	state = State.ON_PLATFORM
	_update_world_position_from_platform()


func _update_waiting(delta: float) -> void:
	var path: AnchorPathSnapshot = _paths.choose_nearest_path(_enemy.global_position.x)
	if path != null:
		selected_anchor_id = path.anchor_id
		state = State.RUNNING_TO_ANCHOR
		return

	_enemy.global_position.x = move_toward(
		_enemy.global_position.x,
		_platform.global_position.x,
		_balance.ground_move_speed * delta
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

	_enemy.global_position.x = move_toward(
		_enemy.global_position.x,
		path.ground_point.x,
		_balance.ground_move_speed * delta
	)
	_set_ground_height()

	if absf(_enemy.global_position.x - path.ground_point.x) > _balance.ground_arrival_epsilon:
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
	_climb_progress = minf(
		1.0,
		_climb_progress + _balance.climb_move_speed * delta / rope_length
	)
	_enemy.global_position = path.ground_point.lerp(
		path.platform_point,
		_climb_progress
	)

	if _climb_progress < 1.0:
		return

	_platform_local_x = path.platform_point.x - _platform.global_position.x
	state = State.ON_PLATFORM
	_update_world_position_from_platform()


func _update_on_platform(delta: float) -> void:
	_update_world_position_from_platform()
	if _melee.is_attacking():
		state = State.FIGHTING
		return

	var target: Defender = _crew.get_nearest_living_defender(_enemy.global_position)
	if target == null:
		state = State.ON_PLATFORM
		return

	var target_local_x: float = target.global_position.x - _platform.global_position.x
	var distance: float = absf(target_local_x - _platform_local_x)
	if distance <= _balance.enemy_attack_range:
		if _melee.try_start(target.health):
			state = State.FIGHTING
		return

	_platform_local_x = move_toward(
		_platform_local_x,
		target_local_x,
		_balance.platform_move_speed * delta
	)
	state = State.ON_PLATFORM
	_update_world_position_from_platform()


func _set_ground_height() -> void:
	_enemy.global_position.y = (
		_orbs.catalog.ground_y - _balance.ground_vertical_offset
	)


func _update_world_position_from_platform() -> void:
	_enemy.global_position = _platform.global_position + Vector2(
		_platform_local_x,
		_balance.platform_local_y
	)
