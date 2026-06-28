class_name FlyingEnemySpawnDirector
extends Node

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("StrategicWaveDirector") var wave_director_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("AnchorPathRegistry") var path_registry_path: NodePath
@export_node_path("BoardingEnemyRegistry") var enemy_registry_path: NodePath
@export_node_path("BoardingMovementResolver") var movement_resolver_path: NodePath
@export_node_path("BoardingJumpPlanner") var jump_planner_path: NodePath
@export_node_path("CrewManager") var crew_manager_path: NodePath
@export_node_path("GroundOrbRegistry") var orb_registry_path: NodePath
@export var enemy_container_path: NodePath
@export var enemy_scene: PackedScene
@export var boarding_balance: BoardingBalance
@export var profile: FlyingEnemyProfile
@export_range(0, 100, 1) var first_flying_wave_number: int = 10

var _spawn_remaining: float = 0.0
var _flying_unlocked: bool = false
var _rng := RandomNumberGenerator.new()

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _wave_director: StrategicWaveDirector = get_node(wave_director_path)
@onready var _platform: PlatformController = get_node(platform_path)
@onready var _paths: AnchorPathRegistry = get_node(path_registry_path)
@onready var _registry: BoardingEnemyRegistry = get_node(enemy_registry_path)
@onready var _movement_resolver: BoardingMovementResolver = get_node(movement_resolver_path)
@onready var _jump_planner: BoardingJumpPlanner = get_node(jump_planner_path)
@onready var _crew: CrewManager = get_node(crew_manager_path)
@onready var _orbs: GroundOrbRegistry = get_node(orb_registry_path)
@onready var _container: Node2D = get_node(enemy_container_path)


func _ready() -> void:
	assert(enemy_scene != null, "FlyingEnemySpawnDirector requires enemy scene")
	assert(boarding_balance != null, "FlyingEnemySpawnDirector requires boarding balance")
	assert(profile != null and profile.is_valid(), "Flying enemy profile is invalid")
	_rng.randomize()
	_game_flow.run_state_changed.connect(_on_run_state_changed)
	reset_spawn_timer()


func _physics_process(delta: float) -> void:
	if _game_flow.state != GameFlowController.RunState.RUNNING:
		return
	if _wave_director.get_wave_number() < first_flying_wave_number:
		_flying_unlocked = false
		return
	if not _flying_unlocked:
		_flying_unlocked = true
		reset_spawn_timer()
		return

	_spawn_remaining = maxf(0.0, _spawn_remaining - delta)
	if _spawn_remaining > 0.0:
		return
	spawn_now()
	reset_spawn_timer()


func spawn_now(side: int = 0) -> BoardingEnemy:
	var resolved_side: int = side
	if resolved_side == 0:
		resolved_side = -1 if _rng.randf() < 0.5 else 1
	var enemy: BoardingEnemy = enemy_scene.instantiate() as BoardingEnemy
	assert(enemy != null, "Flying enemy scene root must use BoardingEnemy")
	_container.add_child(enemy)
	enemy.configure(
		profile.archetype,
		boarding_balance,
		_game_flow,
		_platform,
		_paths,
		_crew,
		_orbs,
		_movement_resolver,
		_jump_planner
	)
	var behavior := FlyingEnemyBehavior.new()
	behavior.setup(profile, _platform, _crew, _registry, enemy.melee)
	enemy.attach_special_behavior(behavior, _game_flow)
	_registry.register_enemy(enemy)
	enemy.global_position = Vector2(
		_platform.global_position.x + float(resolved_side) * profile.spawn_distance,
		_platform.global_position.y - profile.hover_height
	)
	return enemy


func get_current_spawn_interval() -> float:
	return profile.get_spawn_interval(
		_wave_director.get_current_difficulty(),
		_wave_director.get_current_overtime_tier()
	)


func reset_spawn_timer() -> void:
	_spawn_remaining = get_current_spawn_interval()


func get_spawn_remaining() -> float:
	return maxf(0.0, _spawn_remaining)


func _on_run_state_changed(previous_state: int, new_state: int) -> void:
	if new_state != GameFlowController.RunState.START_DELAY:
		return
	if previous_state == GameFlowController.RunState.MANUAL_PAUSE:
		return
	_flying_unlocked = false
	reset_spawn_timer()
