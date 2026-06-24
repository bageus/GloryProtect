class_name CombatAnchorBalance
extends Resource

@export_range(1, 20, 1) var periodic_damage: int = 1
@export_range(0.1, 20.0, 0.1) var periodic_interval_seconds: float = 4.0
@export_range(0.1, 1.0, 0.05) var advanced_periodic_interval_multiplier: float = 0.5
@export_range(0.0, 10.0, 0.1) var strong_overload_bonus_seconds: float = 1.0
@export_range(1.0, 5.0, 0.05) var second_anchor_install_speed_multiplier: float = 1.5
@export_range(0.0, 1.0, 0.01) var spontaneous_fall_chance: float = 0.25
@export_range(1, 20, 1) var electric_pulse_damage: int = 1
@export_range(0.0, 10.0, 0.1) var electric_stun_seconds: float = 2.0
@export_range(0.0, 1.0, 0.01) var electric_stun_chance: float = 0.3
@export_range(0.0, 1.0, 0.01) var electric_drop_chance: float = 0.5
@export_range(0.0, 500.0, 1.0) var endpoint_pulse_radius: float = 130.0
@export_range(1, 20, 1) var trap_remove_damage: int = 1
@export_range(0.0, 500.0, 1.0) var trap_remove_radius: float = 145.0
@export_range(0.0, 500.0, 1.0) var trap_knockback_distance: float = 90.0
@export_range(1, 20, 1) var trap_attach_damage: int = 1
@export_range(0.0, 500.0, 1.0) var trap_attach_radius: float = 145.0


func is_valid() -> bool:
	return (
		periodic_damage > 0
		and periodic_interval_seconds > 0.0
		and advanced_periodic_interval_multiplier > 0.0
		and advanced_periodic_interval_multiplier < 1.0
		and strong_overload_bonus_seconds >= 0.0
		and second_anchor_install_speed_multiplier >= 1.0
		and spontaneous_fall_chance >= 0.0
		and spontaneous_fall_chance <= 1.0
		and electric_pulse_damage > 0
		and electric_stun_seconds >= 0.0
		and electric_stun_chance >= 0.0
		and electric_stun_chance <= 1.0
		and electric_drop_chance >= 0.0
		and electric_drop_chance <= 1.0
		and endpoint_pulse_radius >= 0.0
		and trap_remove_damage > 0
		and trap_remove_radius >= 0.0
		and trap_knockback_distance >= 0.0
		and trap_attach_damage > 0
		and trap_attach_radius >= 0.0
	)


func get_periodic_interval(advanced: bool) -> float:
	if advanced:
		return periodic_interval_seconds * advanced_periodic_interval_multiplier
	return periodic_interval_seconds
