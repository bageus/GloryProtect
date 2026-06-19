class_name BoardingBalance
extends Resource

@export_range(1, 20, 1) var enemy_max_health: int = 1
@export_range(20.0, 500.0, 1.0) var ground_move_speed: float = 125.0
@export_range(20.0, 500.0, 1.0) var climb_move_speed: float = 105.0
@export_range(20.0, 500.0, 1.0) var platform_move_speed: float = 90.0
@export_range(4.0, 40.0, 1.0) var enemy_body_radius: float = 12.0
@export_range(0.0, 100.0, 1.0) var ground_vertical_offset: float = 12.0
@export_range(-100.0, 100.0, 1.0) var platform_local_y: float = -48.0
@export_range(0.0, 100.0, 1.0) var ground_arrival_epsilon: float = 8.0
@export_range(10.0, 1000.0, 1.0) var spawn_distance_from_platform: float = 720.0
@export_range(0.1, 30.0, 0.1) var spawn_interval: float = 3.0
@export_range(1, 100, 1) var max_ground_enemies: int = 8
@export_range(0.0, 200.0, 1.0) var path_tie_epsilon: float = 24.0

@export_range(1, 20, 1) var enemy_attack_damage: int = 1
@export_range(0.05, 5.0, 0.05) var enemy_attack_windup: float = 0.55
@export_range(0.05, 5.0, 0.05) var enemy_attack_cooldown: float = 0.85
@export_range(5.0, 200.0, 1.0) var enemy_attack_range: float = 30.0

@export_range(1, 20, 1) var defender_attack_damage: int = 1
@export_range(0.05, 5.0, 0.05) var defender_attack_windup: float = 0.38
@export_range(0.05, 5.0, 0.05) var defender_attack_cooldown: float = 0.62
@export_range(5.0, 200.0, 1.0) var defender_attack_range: float = 34.0
@export_range(10.0, 500.0, 1.0) var post_combat_radius: float = 150.0
