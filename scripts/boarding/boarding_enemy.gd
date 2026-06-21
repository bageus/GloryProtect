class_name BoardingEnemy
extends Node2D

signal died(enemy_id: int, reason: StringName)

@export_node_path("HealthComponent") var health_path: NodePath
@export_node_path("MeleeAttackComponent") var melee_path: NodePath
@export_node_path("BoardingEnemyBehavior") var controller_path: NodePath
@export_node_path("Node2D") var visual_path: NodePath

var enemy_id: int = -1
var archetype: BoardingEnemyArchetype
var _dead: bool = false

@onready var health: HealthComponent = get_node(health_path)
@onready var melee: MeleeAttackComponent = get_node(melee_path)
@onready var controller: BoardingEnemyBehavior = get_node(controller_path)
@onready var visual: Node2D = get_node(visual_path)


func _ready() -> void:
	health.depleted.connect(_on_health_depleted)


func set_enemy_id(value: int) -> void:
	enemy_id = value
	name = "BoardingEnemy%d" % (enemy_id + 1)


func configure(
	profile: BoardingEnemyArchetype,
	balance: BoardingBalance,
	game_flow: GameFlowController,
	platform: PlatformController,
	paths: AnchorPathRegistry,
	crew: CrewManager,
	orbs: GroundOrbRegistry,
	movement_resolver: BoardingMovementResolver,
	jump_planner: BoardingJumpPlanner,
	anchors: AnchorSystem
) -> void:
	assert(profile != null, "BoardingEnemy requires an archetype")
	assert(profile.is_valid(), "BoardingEnemy archetype is invalid")
	archetype = profile
	health.configure(archetype.max_health)
	melee.configure(
		archetype.attack_damage,
		archetype.attack_windup,
		archetype.attack_cooldown
	)
	visual.call("configure", archetype)
	controller.configure(
		self,
		archetype,
		balance,
		game_flow,
		platform,
		paths,
		crew,
		orbs,
		movement_resolver,
		jump_planner,
		melee,
		anchors
	)


func kill(reason: StringName) -> void:
	if _dead:
		return
	_dead = true
	controller.stop()
	melee.cancel()
	visible = false
	died.emit(enemy_id, reason)
	call_deferred("queue_free")


func get_state() -> int:
	return controller.get_state()


func get_selected_anchor_id() -> int:
	return controller.get_selected_anchor_id()


func is_grounded_for_limit() -> bool:
	return controller.is_grounded_for_limit()


func is_climbing() -> bool:
	return controller.is_climbing()


func is_on_platform() -> bool:
	return controller.is_on_platform()


func is_turret_targetable() -> bool:
	return controller.is_turret_targetable()


func force_board_at(local_x: float) -> void:
	controller.force_board_at(local_x)


func get_archetype_id() -> StringName:
	if archetype == null:
		return &""
	return archetype.archetype_id


func get_archetype_name() -> String:
	if archetype == null:
		return "Не настроен"
	return archetype.display_name


func get_body_radius() -> float:
	if archetype == null:
		return 0.0
	return archetype.body_radius


func _on_health_depleted() -> void:
	kill(&"combat")
