class_name BoardingEnemy
extends Node2D

signal died(enemy_id: int, reason: StringName)

@export_node_path("HealthComponent") var health_path: NodePath
@export_node_path("MeleeAttackComponent") var melee_path: NodePath
@export_node_path("BoardingEnemyController") var controller_path: NodePath
@export_node_path("BoardingEnemyVisual") var visual_path: NodePath

var enemy_id: int = -1
var _dead: bool = false

@onready var health: HealthComponent = get_node(health_path)
@onready var melee: MeleeAttackComponent = get_node(melee_path)
@onready var controller: BoardingEnemyController = get_node(controller_path)
@onready var visual: BoardingEnemyVisual = get_node(visual_path)


func _ready() -> void:
	health.depleted.connect(_on_health_depleted)


func set_enemy_id(value: int) -> void:
	enemy_id = value
	name = "BoardingEnemy%d" % (enemy_id + 1)


func configure(
	balance: BoardingBalance,
	game_flow: GameFlowController,
	platform: PlatformController,
	paths: AnchorPathRegistry,
	crew: CrewManager,
	orbs: GroundOrbRegistry,
	movement_resolver: BoardingMovementResolver
) -> void:
	health.configure(balance.enemy_max_health)
	melee.configure(
		balance.enemy_attack_damage,
		balance.enemy_attack_windup,
		balance.enemy_attack_cooldown
	)
	visual.configure(balance.enemy_body_radius)
	controller.configure(
		self,
		balance,
		game_flow,
		platform,
		paths,
		crew,
		orbs,
		movement_resolver,
		melee
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


func is_on_platform() -> bool:
	return controller.is_on_platform()


func force_board_at(local_x: float) -> void:
	controller.force_board_at(local_x)


func _on_health_depleted() -> void:
	kill(&"combat")
