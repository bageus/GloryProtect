class_name BoardingEnemy
extends Node2D

signal died(enemy_id: int, reason: StringName)
signal visual_state_changed(enemy_id: int, state_id: StringName)
signal stun_changed(enemy_id: int, remaining_seconds: float)
signal damage_mark_changed(enemy_id: int, remaining_seconds: float)

@export_node_path("HealthComponent") var health_path: NodePath
@export_node_path("MeleeAttackComponent") var melee_path: NodePath
@export_node_path("BoardingEnemyController") var controller_path: NodePath
@export_node_path("BoardingEnemyVisual") var visual_path: NodePath

var enemy_id: int = -1
var archetype: BoardingEnemyArchetype
var behavior: EnemyBehaviorComponent
var _dead: bool = false
var _stun_remaining: float = 0.0
var _damage_mark_remaining: float = 0.0
var _damage_mark_multiplier: float = 1.0
var _game_flow: GameFlowController
var _fall_landing_y: float = 0.0

@onready var health: HealthComponent = get_node(health_path)
@onready var melee: MeleeAttackComponent = get_node(melee_path)
@onready var controller: BoardingEnemyController = get_node(controller_path)
@onready var visual: BoardingEnemyVisual = get_node(visual_path)


func _ready() -> void:
	health.depleted.connect(_on_health_depleted)


func _physics_process(delta: float) -> void:
	if _game_flow == null or not _game_flow.is_world_simulation_active():
		return
	var safe_delta: float = maxf(0.0, delta)
	if _stun_remaining > 0.0:
		_stun_remaining = maxf(0.0, _stun_remaining - safe_delta)
		stun_changed.emit(enemy_id, _stun_remaining)
	if _damage_mark_remaining > 0.0:
		_damage_mark_remaining = maxf(0.0, _damage_mark_remaining - safe_delta)
		if _damage_mark_remaining <= 0.0:
			_damage_mark_multiplier = 1.0
			health.set_incoming_damage_multiplier(1.0)
		damage_mark_changed.emit(enemy_id, _damage_mark_remaining)


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
	_game_flow = game_flow
	_fall_landing_y = orbs.catalog.ground_y - balance.ground_vertical_offset
	_stun_remaining = 0.0
	_damage_mark_remaining = 0.0
	_damage_mark_multiplier = 1.0
	health.configure(archetype.max_health)
	melee.configure(archetype.attack_damage, archetype.attack_windup, archetype.attack_cooldown, self)
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


func attach_special_behavior(component: EnemyBehaviorComponent, game_flow: GameFlowController) -> void:
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


func apply_stun(duration_seconds: float) -> bool:
	if duration_seconds <= 0.0 or _dead or not health.is_alive():
		return false
	_stun_remaining = maxf(_stun_remaining, duration_seconds)
	melee.cancel()
	stun_changed.emit(enemy_id, _stun_remaining)
	return true


func apply_damage_mark(duration_seconds: float, damage_multiplier: float) -> bool:
	if duration_seconds <= 0.0 or damage_multiplier <= 1.0:
		return false
	if _dead or not health.is_alive():
		return false
	_damage_mark_remaining = maxf(_damage_mark_remaining, duration_seconds)
	_damage_mark_multiplier = maxf(_damage_mark_multiplier, damage_multiplier)
	health.set_incoming_damage_multiplier(_damage_mark_multiplier)
	damage_mark_changed.emit(enemy_id, _damage_mark_remaining)
	return true


func knock_down_from_anchor(reason: StringName = &"shooter_anchor_knockdown") -> bool:
	if _dead or not health.is_alive() or not is_counted_as_climbing():
		return false
	_kill_internal(reason, true)
	return true


func apply_platform_knockback(distance: float, source_world_x: float) -> void:
	if distance <= 0.0 or behavior != null or not controller.is_on_platform():
		return
	var direction: float = signf(global_position.x - source_world_x)
	if is_zero_approx(direction):
		direction = 1.0
	controller.force_board_at(controller.get_platform_local_x() + direction * distance)


func is_stunned() -> bool:
	return _stun_remaining > 0.0


func get_stun_remaining() -> float:
	return maxf(0.0, _stun_remaining)


func is_damage_marked() -> bool:
	return _damage_mark_remaining > 0.0


func get_damage_mark_remaining() -> float:
	return maxf(0.0, _damage_mark_remaining)


func get_target_domain() -> int:
	if behavior != null:
		return behavior.target_domain
	return EnemyBehaviorComponent.TargetDomain.GROUND


func kill(reason: StringName) -> void:
	_kill_internal(reason, false)


func _kill_internal(reason: StringName, use_fall_visual: bool) -> void:
	if _dead:
		return
	_dead = true
	_stun_remaining = 0.0
	_damage_mark_remaining = 0.0
	_damage_mark_multiplier = 1.0
	health.set_incoming_damage_multiplier(1.0)
	if behavior != null:
		behavior.stop()
	controller.stop()
	melee.cancel()
	if use_fall_visual:
		visual.detach_for_fall(_fall_landing_y)
	else:
		visual.detach_for_death()
	visible = false
	died.emit(enemy_id, reason)
	call_deferred("queue_free")


func get_state() -> int:
	if behavior != null:
		return -1
	return controller.get_state()


func get_selected_anchor_id() -> int:
	if behavior != null:
		return behavior.get_selected_anchor_id()
	return controller.get_selected_anchor_id()


func is_on_platform() -> bool:
	if behavior != null:
		return behavior.is_counted_as_boarded()
	return controller.is_on_platform()


func is_targetable_by_turret() -> bool:
	if not health.is_alive():
		return false
	if behavior != null:
		return behavior.is_targetable_by_turret()
	return controller.get_state() == BoardingEnemyController.State.CLIMBING or controller.is_on_platform()


func is_counted_as_ground() -> bool:
	if behavior != null:
		return behavior.is_counted_as_ground()
	var enemy_state: int = controller.get_state()
	return enemy_state == BoardingEnemyController.State.WAITING_WITHOUT_PATH or enemy_state == BoardingEnemyController.State.RUNNING_TO_ANCHOR


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
