class_name MedicUpgradeBalance
extends Resource

@export_group("Field Medic")
@export var field_attack: MedicAttackDefinition
@export_range(0.0, 2.0, 0.05) var field_move_speed_bonus_ratio: float = 0.15
@export_range(0.05, 1.0, 0.05) var emergency_heal_interval_multiplier: float = 0.5
@export_range(1, 10, 1) var emergency_health_threshold: int = 1

@export_group("Combat Stimulant")
@export_range(0.1, 30.0, 0.1) var stimulant_duration: float = 5.0
@export_range(0.0, 2.0, 0.05) var stimulant_attack_speed_bonus_ratio: float = 0.15
@export_range(0.0, 2.0, 0.05) var stimulant_move_speed_bonus_ratio: float = 0.15
@export_range(1.0, 300.0, 1.0) var revival_cooldown: float = 60.0

@export_group("Protective Healing")
@export_range(1, 10, 1) var armor_per_healed_segment: int = 1
@export_range(0.05, 1.0, 0.05) var chain_heal_ratio: float = 0.5


func is_valid() -> bool:
	return (
		field_attack != null
		and field_attack.is_valid()
		and field_move_speed_bonus_ratio >= 0.0
		and emergency_heal_interval_multiplier > 0.0
		and emergency_heal_interval_multiplier <= 1.0
		and emergency_health_threshold > 0
		and stimulant_duration > 0.0
		and stimulant_attack_speed_bonus_ratio >= 0.0
		and stimulant_move_speed_bonus_ratio >= 0.0
		and revival_cooldown > 0.0
		and armor_per_healed_segment > 0
		and chain_heal_ratio > 0.0
		and chain_heal_ratio <= 1.0
	)
