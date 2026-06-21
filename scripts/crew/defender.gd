class_name Defender
extends Node2D

signal destination_reached(defender_id: int)
signal died(defender_id: int)

@export_node_path("HealthComponent") var health_path: NodePath
@export_node_path("DefenderDurabilityComponent") var durability_path: NodePath
@export_node_path("StatusEffectComponent") var status_effects_path: NodePath
@export_node_path("DefenderMovement") var movement_path: NodePath
@export_node_path("DefenderVisual") var visual_path: NodePath
@export_node_path("MeleeAttackComponent") var melee_path: NodePath
@export_node_path("DefenderCombatController") var combat_path: NodePath

var defender_id: int = -1
var _balance: CrewBalance
var _body_color: Color = Color(0.45, 0.8, 1.0)
var _melee_upgrades: MeleeDefenderUpgradeRuntime
var _configured_once: bool = false
var _lethal_guard_feature_enabled: bool = false
var _base_movement_speed: float = 180.0
var _medic_role_active: bool = false
var _medic_combat_enabled: bool = false
var _medic_healing_action_active: bool = false
var _medic_damage_bonus: int = 0
var _medic_move_speed_multiplier: float = 1.0

@onready var health: HealthComponent = get_node(health_path)
@onready var durability: DefenderDurabilityComponent = get_node(durability_path)
@onready var status_effects: StatusEffectComponent = get_node(status_effects_path)
@onready var movement: DefenderMovement = get_node(movement_path)
@onready var visual: DefenderVisual = get_node(visual_path)
@onready var melee: MeleeAttackComponent = get_node(melee_path)
@onready var combat: DefenderCombatController = get_node(combat_path)


func _ready() -> void:
	movement.destination_reached.connect(_on_destination_reached)
	health.depleted.connect(_on_depleted)
	health.set_durability_component(durability)
	_apply_configuration(false)


func configure(
	new_defender_id: int,
	balance: CrewBalance,
	body_color: Color,
	melee_upgrades: MeleeDefenderUpgradeRuntime = null
) -> void:
	defender_id = new_defender_id
	_balance = balance
	_body_color = body_color
	_melee_upgrades = melee_upgrades
	_base_movement_speed = balance.defender_move_speed
	if is_node_ready():
		_apply_configuration(false)


func apply_melee_upgrades(
	upgrades: MeleeDefenderUpgradeRuntime
) -> void:
	_melee_upgrades = upgrades
	if is_node_ready():
		_apply_configuration(false)


func reset_melee_upgrades_for_new_life(
	upgrades: MeleeDefenderUpgradeRuntime
) -> void:
	_melee_upgrades = upgrades
	if is_node_ready():
		_apply_configuration(true)


func get_melee_upgrades() -> MeleeDefenderUpgradeRuntime:
	return _melee_upgrades


func set_base_movement_speed(speed: float) -> void:
	_base_movement_speed = maxf(0.0, speed)
	if is_node_ready():
		_refresh_action_configuration()


func set_medic_role_modifiers(
	active: bool,
	combat_enabled: bool,
	damage_bonus: int,
	move_speed_multiplier: float
) -> void:
	_medic_role_active = active
	_medic_combat_enabled = active and combat_enabled
	_medic_damage_bonus = maxi(0, damage_bonus) if active else 0
	_medic_move_speed_multiplier = (
		maxf(0.0, move_speed_multiplier) if active else 1.0
	)
	if not active:
		_medic_healing_action_active = false
	if is_node_ready():
		_refresh_action_configuration()


func set_medic_healing_action_active(active: bool) -> void:
	_medic_healing_action_active = _medic_role_active and active


func can_medic_role_use_melee() -> bool:
	return (
		_medic_role_active
		and _medic_combat_enabled
		and not _medic_healing_action_active
		and health.is_alive()
	)


func blocks_enemy_jump() -> bool:
	return (
		_melee_upgrades != null
		and _melee_upgrades.heavy_blocks_jump
		and health.is_alive()
	)


func move_to(local_x: float) -> void:
	if health.is_alive():
		movement.move_to(local_x)


func teleport_to(local_x: float) -> void:
	movement.teleport_to(local_x)


func is_moving() -> bool:
	return movement.is_moving()


func is_combat_action_active() -> bool:
	return combat.is_action_active()


func _apply_configuration(reset_life_state: bool) -> void:
	if _balance == null:
		return
	var max_health: int = _balance.defender_max_health
	var armor: int = 0
	var lethal_guard: bool = false
	if _melee_upgrades != null:
		max_health = _melee_upgrades.get_max_health(max_health)
		armor = maxi(0, _melee_upgrades.armor_bonus)
		lethal_guard = _melee_upgrades.assault_lethal_guard
	if not _configured_once or reset_life_state:
		health.configure(max_health)
		durability.configure(armor, lethal_guard)
		_configured_once = true
	else:
		health.set_max_health(max_health, true)
		durability.set_max_armor(armor)
		if lethal_guard and not _lethal_guard_feature_enabled:
			durability.set_lethal_guard_available(true)
		elif not lethal_guard:
			durability.set_lethal_guard_available(false)
	_lethal_guard_feature_enabled = lethal_guard
	_refresh_action_configuration()
	visual.configure(_balance.defender_body_radius, _body_color)
	position.y = _balance.defender_local_y
	visible = true


func _refresh_action_configuration() -> void:
	if _balance == null:
		return
	var damage: int = 1
	var cooldown: float = 0.7
	if _melee_upgrades != null:
		damage = _melee_upgrades.get_damage(damage)
		cooldown = _melee_upgrades.get_cooldown(cooldown)
	if _medic_role_active and _medic_combat_enabled:
		damage += _medic_damage_bonus
	melee.configure(damage, 0.4, cooldown, self)
	movement.configure(_base_movement_speed * _medic_move_speed_multiplier)


func _on_destination_reached() -> void:
	destination_reached.emit(defender_id)


func _on_depleted() -> void:
	status_effects.clear_poison()
	movement.stop()
	combat.cancel()
	visible = false
	died.emit(defender_id)
