class_name RangedAttackVisual
extends Node2D

@export_node_path("RangedAttackComponent") var attack_path: NodePath
@export var projectile_color: Color = Color(0.65, 1.0, 0.35)
@export_range(1.0, 20.0, 1.0) var projectile_radius: float = 4.0

var _projectile_visible: bool = false
var _projectile_world_position := Vector2.ZERO

@onready var _attack: RangedAttackComponent = get_node(attack_path)


func _ready() -> void:
	_attack.projectile_launched.connect(_on_projectile_launched)
	_attack.projectile_moved.connect(_on_projectile_moved)
	_attack.attack_finished.connect(_on_attack_finished)


func _draw() -> void:
	if not _projectile_visible:
		return
	var local_position: Vector2 = to_local(_projectile_world_position)
	draw_circle(local_position, projectile_radius, projectile_color)
	draw_arc(
		local_position,
		projectile_radius + 2.0,
		0.0,
		TAU,
		16,
		projectile_color.lightened(0.25),
		1.5
	)


func _on_projectile_launched(
	_target: HealthComponent,
	start_position: Vector2,
	_target_position: Vector2
) -> void:
	_projectile_visible = true
	_projectile_world_position = start_position
	queue_redraw()


func _on_projectile_moved(position: Vector2) -> void:
	_projectile_world_position = position
	queue_redraw()


func _on_attack_finished() -> void:
	_projectile_visible = false
	queue_redraw()
