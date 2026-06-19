class_name BoardingSpawnDirector
extends Node

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("AnchorPathRegistry") var path_registry_path: NodePath
@export_node_path("BoardingEnemyRegistry") var enemy_registry_path: NodePath
@export_node_path("BoardingMovementResolver") var movement_resolver_path: NodePath
@export_node_path("BoardingJumpPlanner") var jump_planner_path: NodePath
@export_node_path("CrewManager") var crew_manager_path: NodePath
@export_node_path("GroundOrbRegistry") var orb_registry_path: NodePath
@export var enemy_container_path: NodePath
@export var enemy_scene: PackedScene
@export var balance: BoardingBalance

var _spawn_remaining: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _platform: PlatformController = get_node(platform_path)
@onready var _paths: AnchorPathRegistry = get_node(path_registry_path)
@onready var _registry: BoardingEnemyRegistry = get_node(enemy_registry_path)
@onready var _movement_resolver: BoardingMovementResolver = get_node(
	movement_resolver_path
)
@onready var _jump_planner: BoardingJumpPlanner = get_node(jump_planner_path)
@onready var _crew: CrewManager = get_node(crew_manager_path)
@onready var _orbs: GroundOrbRegistry = get_node(orb_registry_path)
@onready var _container: Node2D = get_node(enemy_container_path)


func _ready() -> void:
	assert(enemy_scene != null, "BoardingSpawnDirector requires enemy scene")
	assert(balance != null, "BoardingSpawnDirector requires BoardingBalance")
	_rng.randomize()
	_spawn_remaining = balance.spawn_interval


func _physics_process(delta: float) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	if not _paths.has_available_paths():
		_spawn_remaining = balance.spawn_interval
		return
	if _registry.get_ground_count() >= balance.max_ground_enemies:
		return

	_spawn_remaining -= delta
	if _spawn_remaining > 0.0:
		return

	spawn_now()
	_spawn_remaining = balance.spawn_interval


func spawn_now() -> BoardingEnemy:
	if not _paths.has_available_paths():
		return null
	var side: int = 1
	if _rng.randf() < 0.5:
		side = -1
	return _spawn_enemy(side)


func spawn_debug_on_platform(local_x: float = 0.0) -> BoardingEnemy:
	var enemy: BoardingEnemy = _spawn_enemy(1)
	enemy.force_board_at(local_x)
	return enemy


func _spawn_enemy(side: int) -> BoardingEnemy:
	var enemy: BoardingEnemy = enemy_scene.instantiate() as BoardingEnemy
	assert(enemy != null, "Boarding enemy scene root must use BoardingEnemy")
	_container.add_child(enemy)
	_registry.register_enemy(enemy)
	enemy.configure(
		balance,
		_game_flow,
		_platform,
		_paths,
		_crew,
		_orbs,
		_movement_resolver,
		_jump_planner
	)
	var preferred_x: float = (
		_platform.global_position.x
		+ float(side) * balance.spawn_distance_from_platform
	)
	enemy.global_position = Vector2(
		_movement_resolver.find_ground_spawn_x(enemy, preferred_x, side),
		_orbs.catalog.ground_y - balance.ground_vertical_offset
	)
	return enemy
