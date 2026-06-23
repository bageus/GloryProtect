class_name CrewCombatCoordinator
extends Node

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("CrewManager") var crew_manager_path: NodePath
@export_node_path("CrewRoleManager") var role_manager_path: NodePath
@export_node_path("BoardingEnemyRegistry") var enemy_registry_path: NodePath
@export_node_path("BoardingMovementResolver") var movement_resolver_path: NodePath
@export var balance: BoardingBalance

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _platform: PlatformController = get_node(platform_path)
@onready var _crew: CrewManager = get_node(crew_manager_path)
@onready var _roles: CrewRoleManager = get_node(role_manager_path)
@onready var _enemies: BoardingEnemyRegistry = get_node(enemy_registry_path)
@onready var _movement_resolver: BoardingMovementResolver = get_node(movement_resolver_path)


func _ready() -> void:
	assert(balance != null, "CrewCombatCoordinator requires BoardingBalance")
	_crew.defender_spawned.connect(_on_defender_spawned)
	call_deferred("_configure_existing_defenders")


func _configure_existing_defenders() -> void:
	for defender: Defender in _crew.get_all_defenders():
		_configure_defender(defender)


func _configure_defender(defender: Defender) -> void:
	defender.movement.configure_collision(defender, _movement_resolver)
	defender.melee.configure(
		balance.defender_attack_damage,
		balance.defender_attack_windup,
		balance.defender_attack_cooldown
	)
	defender.combat.configure(
		defender,
		balance,
		_game_flow,
		_platform,
		_roles,
		_enemies,
		defender.melee
	)
	defender.shooter_combat.configure(
		defender,
		_game_flow,
		_roles,
		_enemies,
		_crew,
		defender.ranged
	)


func _on_defender_spawned(_defender_id: int, defender: Defender) -> void:
	_configure_defender(defender)
