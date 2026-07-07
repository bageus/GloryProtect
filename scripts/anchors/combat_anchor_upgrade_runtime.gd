class_name CombatAnchorUpgradeRuntime
extends RefCounted

const STRONG: StringName = &"anchor_specialization_strong"
const ELECTRIC: StringName = &"anchor_specialization_electric"
const TRAP: StringName = &"anchor_specialization_trap"

const REINFORCED_WIND_THRESHOLD: StringName = &"anchor_reinforced_wind_threshold"
const SECOND_WINCH_PAIR: StringName = &"anchor_second_winch_pair"
const OVERLOAD_BONUS_SECONDS: StringName = &"anchor_overload_bonus_seconds"
const PERIODIC_ELECTRIC: StringName = &"anchor_periodic_electric"
const PERIODIC_ELECTRIC_ADVANCED: StringName = &"anchor_periodic_electric_advanced"
const INSTALL_SPEED_BONUS_RATIO: StringName = &"anchor_install_speed_bonus_ratio"
const INSTANT_REMOVE_ALL: StringName = &"anchor_instant_remove_all"
const STRONG_SECOND_INSTALL: StringName = &"anchor_strong_second_install"
const STRONG_CLIMBER_FALL: StringName = &"anchor_strong_climber_fall"
const ELECTRIC_DROP: StringName = &"anchor_electric_drop"
const TRAP_ATTACH_EXPLOSION: StringName = &"anchor_trap_attach_explosion"

var overload_bonus_seconds: float = 0.0
var install_speed_bonus_ratio: float = 0.0
var reinforced_wind_threshold_enabled: bool = false
var second_winch_pair_enabled: bool = false
var periodic_electric_enabled: bool = false
var periodic_electric_advanced: bool = false
var instant_remove_all_enabled: bool = false
var specialization_id: StringName = &""
var strong_second_install_enabled: bool = false
var strong_climber_fall_enabled: bool = false
var electric_drop_enabled: bool = false
var trap_attach_explosion_enabled: bool = false


func reset() -> void:
	overload_bonus_seconds = 0.0
	install_speed_bonus_ratio = 0.0
	reinforced_wind_threshold_enabled = false
	second_winch_pair_enabled = false
	periodic_electric_enabled = false
	periodic_electric_advanced = false
	instant_remove_all_enabled = false
	specialization_id = &""
	strong_second_install_enabled = false
	strong_climber_fall_enabled = false
	electric_drop_enabled = false
	trap_attach_explosion_enabled = false


func can_apply_effect(effect: UpgradeEffectDefinition) -> bool:
	if effect == null:
		return false
	match effect.effect_type:
		UpgradeEffectDefinition.EffectType.DOMAIN_SCALAR:
			return _can_apply_scalar(effect.target_id, effect.scalar_value)
		UpgradeEffectDefinition.EffectType.DOMAIN_FLAG:
			return _can_apply_flag(effect.target_id)
	return false


func apply_scalar(target_id: StringName, value: float) -> bool:
	if not _can_apply_scalar(target_id, value):
		return false
	match target_id:
		OVERLOAD_BONUS_SECONDS:
			overload_bonus_seconds += value
			return true
		INSTALL_SPEED_BONUS_RATIO:
			install_speed_bonus_ratio += value
			return true
	return false


func apply_flag(target_id: StringName) -> bool:
	if not _can_apply_flag(target_id):
		return false
	match target_id:
		REINFORCED_WIND_THRESHOLD:
			reinforced_wind_threshold_enabled = true
			return true
		SECOND_WINCH_PAIR:
			second_winch_pair_enabled = true
			return true
		PERIODIC_ELECTRIC:
			periodic_electric_enabled = true
			return true
		PERIODIC_ELECTRIC_ADVANCED:
			periodic_electric_advanced = true
			return true
		INSTANT_REMOVE_ALL:
			instant_remove_all_enabled = true
			return true
		STRONG, ELECTRIC, TRAP:
			specialization_id = target_id
			return true
		STRONG_SECOND_INSTALL:
			strong_second_install_enabled = true
			return true
		STRONG_CLIMBER_FALL:
			strong_climber_fall_enabled = true
			return true
		ELECTRIC_DROP:
			electric_drop_enabled = true
			return true
		TRAP_ATTACH_EXPLOSION:
			trap_attach_explosion_enabled = true
			return true
	return false


func has_strong_specialization() -> bool:
	return specialization_id == STRONG


func has_electric_specialization() -> bool:
	return specialization_id == ELECTRIC


func has_trap_specialization() -> bool:
	return specialization_id == TRAP


func _can_apply_scalar(target_id: StringName, value: float) -> bool:
	if value <= 0.0:
		return false
	return target_id in [
		OVERLOAD_BONUS_SECONDS,
		INSTALL_SPEED_BONUS_RATIO,
	]


func _can_apply_flag(target_id: StringName) -> bool:
	match target_id:
		REINFORCED_WIND_THRESHOLD:
			return not reinforced_wind_threshold_enabled
		SECOND_WINCH_PAIR:
			return reinforced_wind_threshold_enabled and not second_winch_pair_enabled
		PERIODIC_ELECTRIC:
			return not periodic_electric_enabled
		PERIODIC_ELECTRIC_ADVANCED:
			return periodic_electric_enabled and not periodic_electric_advanced
		INSTANT_REMOVE_ALL:
			return not instant_remove_all_enabled
		STRONG, ELECTRIC, TRAP:
			return specialization_id == &""
		STRONG_SECOND_INSTALL:
			return has_strong_specialization() and not strong_second_install_enabled
		STRONG_CLIMBER_FALL:
			return has_strong_specialization() and not strong_climber_fall_enabled
		ELECTRIC_DROP:
			return has_electric_specialization() and not electric_drop_enabled
		TRAP_ATTACH_EXPLOSION:
			return has_trap_specialization() and not trap_attach_explosion_enabled
	return false
