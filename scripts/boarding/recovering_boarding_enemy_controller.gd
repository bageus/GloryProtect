class_name RecoveringBoardingEnemyController
extends SurfaceAlignedBoardingEnemyController


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
	melee: MeleeAttackComponent
) -> void:
	super.configure(
		enemy,
		archetype,
		balance,
		game_flow,
		platform,
		paths,
		crew,
		orbs,
		movement_resolver,
		jump_planner,
		melee
	)
	_connect_path_signals()


func stop() -> void:
	_disconnect_path_signals()
	super.stop()


func _choose_ground_path() -> AnchorPathSnapshot:
	return _paths.choose_nearest_path_deterministic(
		_enemy.global_position.x
	)


func _connect_path_signals() -> void:
	if _paths == null:
		return
	if not _paths.path_opened.is_connected(_on_path_opened):
		_paths.path_opened.connect(_on_path_opened)
	if not _paths.path_closed.is_connected(_on_path_closed):
		_paths.path_closed.connect(_on_path_closed)


func _disconnect_path_signals() -> void:
	if _paths == null:
		return
	if _paths.path_opened.is_connected(_on_path_opened):
		_paths.path_opened.disconnect(_on_path_opened)
	if _paths.path_closed.is_connected(_on_path_closed):
		_paths.path_closed.disconnect(_on_path_closed)


func _on_path_opened(_anchor_id: int) -> void:
	if not _configured or state != State.WAITING_WITHOUT_PATH:
		return
	var path: AnchorPathSnapshot = _choose_ground_path()
	if path == null:
		return
	selected_anchor_id = path.anchor_id
	state = State.RUNNING_TO_ANCHOR


func _on_path_closed(anchor_id: int) -> void:
	if not _configured:
		return
	if state == State.CLIMBING or state == State.ON_PLATFORM:
		return
	if state == State.FIGHTING or state == State.JUMPING:
		return
	if selected_anchor_id != anchor_id:
		return
	selected_anchor_id = -1
	state = State.WAITING_WITHOUT_PATH
