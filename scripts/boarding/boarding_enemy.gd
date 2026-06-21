class_name BoardingEnemy
extends Node2D

signal died(enemy_id: int, reason: StringName)
signal visual_state_changed(enemy_id: int, state_id: StringName)

@export_node_path("HealthComponent") var health_path: NodePath
@export_node_path("MeleeAttackComponent") var melee_path: NodePath
@export_node_path("BoardingEnemyController") var controller_path: NodePath
@export_node_path("BoardingEnemyVisual") var visual_path: NodePath

var enemy_id: int = -1
var archetype: BoardingEnemyArchetype
var behavior: EnemyBehaviorComponent
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
	profile: BoardingEnemyArchetype,
	balance: BoardingBalance,
	game_flow: GameFlowController,
	platform: PlatformController,
	paths: AnchorPathRegistry,
	crew: CrewManager,
	orbs: GroundOrbRegistry,
	movement_resolver: BoardingMovementResolver,
	jump_planner: BoardingJumpPlanner
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
	visual.configure(archetype)
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
		melee
	)


func attach_special_behavior(
	component: EnemyBehaviorComponent,
	game_flow: GameFlowController
) -> void:
	assert(component != null, "Special enemy behavior is required")
	assert(behavior == null, "BoardingEnemy already has a special behavior")
	if component.get_parent() == null:
		add_child(component)
	else:
		assert(component.get_parent() == self, "Behavior must belong to enemy")
	behavior = component
	controller.stop()
	melee.cancel()
	behavior.visual_state_changed.connect(_on_behavior_visual_state_changed)
	behavior.configure(self, game_flow)


func kill(reason: StringName) -> void:
	if _dead:
		return
	_dead = true
	if behavior != null:
		behavior.stop()
	controller.stop()
	melee.cancel()
	visible = false
	died.emit(enemy_id, reason)
	call_deferred("queue_free")


func get_state() -> int:
	if behavior != null:
		return -1
	return controller.get_state()


func is_on_platform() -> bool:
	if behavior != null:
		return behavior.is_counted_as_boarded()
	return controller.is_on_platform()


func is_targetable_by_turret() -> bool:
	if not health.is_alive():
		return false
	if behavior != null:
		return behavior.is_targetable_by_turret()
	return (
		controller.get_state() == BoardingEnemyController.State.CLIMBING
		or controller.is_on_platform()
	)


func is_counted_as_ground() -> bool:
	if behavior != null:
		return behavior.is_counted_as_ground()
	var enemy_state: int = controller.get_state()
	return (
		enemy_state == BoardingEnemyController.State.WAITING_WITHOUT_PATH
		or enemy_state == BoardingEnemyController.State.RUNNING_TO_ANCHOR
	)


func is_counted_as_climbing() -> bool:
	if behavior != null:
		return behavior.is_counted_as_climbing()
	return controller.get_state() == BoardingEnemyController.State.CLIMBING


func is_counted_as_boarded() -> bool:
	if behavior != null:
		return behavior.is_counted_as_boarded()
	return controller.is_on_platform()


func force_board_at(local_x: float) -> void:
	if behavior != null:
		return
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


func _on_behavior_visual_state_changed(state_id: StringName) -> void:
	visual_state_changed.emit(enemy_id, state_id)


func _on_health_depleted() -> void:
	kill(&"combat")
