class_name BoardingEnemyArchetype
extends Resource

@export var archetype_id: StringName = &"basic"
@export var display_name: String = "Базовый абордажник"
@export var behavior_scene: PackedScene

@export_group("Body")
@export_range(1, 20, 1) var max_health: int = 1
@export_range(4.0, 40.0, 1.0) var body_radius: float = 12.0
@export var body_color: Color = Color(0.92, 0.24, 0.2)
@export var accent_color: Color = Color(1.0, 0.72, 0.62)

@export_group("Movement")
@export_range(20.0, 500.0, 1.0) var ground_move_speed: float = 125.0
@export_range(20.0, 500.0, 1.0) var climb_move_speed: float = 105.0
@export_range(20.0, 500.0, 1.0) var platform_move_speed: float = 90.0

@export_group("Combat")
@export_range(1, 20, 1) var attack_damage: int = 1
@export_range(0.05, 5.0, 0.05) var attack_windup: float = 0.55
@export_range(0.05, 5.0, 0.05) var attack_cooldown: float = 0.85
@export_range(5.0, 200.0, 1.0) var attack_range: float = 30.0

@export_group("Spawn Weight")
@export_range(0.0, 1.0, 0.01) var unlock_difficulty: float = 0.0
@export_range(0.0, 20.0, 0.05) var weight_at_unlock: float = 1.0
@export_range(0.0, 20.0, 0.05) var weight_at_max_difficulty: float = 1.0


func instantiate_behavior() -> EnemyBehaviorComponent:
	if behavior_scene == null:
		return null
	var component: EnemyBehaviorComponent = (
		behavior_scene.instantiate() as EnemyBehaviorComponent
	)
	assert(
		component != null,
		"Boarding enemy behavior scene root must use EnemyBehaviorComponent"
	)
	return component


func get_weight(normalized_difficulty: float) -> float:
	var difficulty: float = clampf(normalized_difficulty, 0.0, 1.0)
	if difficulty < unlock_difficulty:
		return 0.0
	var local_progress: float = 1.0
	if unlock_difficulty < 1.0:
		local_progress = inverse_lerp(unlock_difficulty, 1.0, difficulty)
	return maxf(
		0.0,
		lerpf(weight_at_unlock, weight_at_max_difficulty, local_progress)
	)


func is_valid() -> bool:
	return (
		archetype_id != &""
		and max_health > 0
		and body_radius > 0.0
		and ground_move_speed > 0.0
		and climb_move_speed > 0.0
		and platform_move_speed > 0.0
		and attack_damage > 0
		and attack_windup > 0.0
		and attack_cooldown > 0.0
		and attack_range > 0.0
	)
