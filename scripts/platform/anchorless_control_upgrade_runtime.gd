class_name AnchorlessControlUpgradeRuntime
extends RefCounted

const PRECISE: StringName = &"anchorless_specialization_precise"
const SPEED: StringName = &"anchorless_specialization_speed"
const POWERFUL: StringName = &"anchorless_specialization_powerful"

const STEERING_FORCE_BONUS: StringName = &"anchorless_steering_force_bonus_ratio"
const WIND_REDUCTION: StringName = &"anchorless_wind_reduction_ratio"
const RELEASE_DRAG_BONUS: StringName = &"anchorless_release_drag_bonus_ratio"
const AUTO_STEERING: StringName = &"anchorless_auto_steering"
const PRECISE_RECHARGE: StringName = &"anchorless_precise_recharge"
const SPEED_LONG_FLIGHT_RESTORE: StringName = &"anchorless_speed_long_flight_restore"
const SPEED_FRONT_SWEEP: StringName = &"anchorless_speed_front_sweep"
const POWERFUL_GROUND_CORE: StringName = &"anchorless_powerful_ground_core"
const POWERFUL_PLATFORM_CORE: StringName = &"anchorless_powerful_platform_core"

var steering_force_bonus_ratio: float = 0.0
var wind_reduction_ratio: float = 0.0
var release_drag_bonus_ratio: float = 0.0
var automatic_steering_enabled: bool = false
var specialization_id: StringName = &""
var precise_recharge_enabled: bool = false
var long_flight_restore_enabled: bool = false
var front_sweep_enabled: bool = false
var ground_core_enabled: bool = false
var platform_core_enabled: bool = false


func reset() -> void:
	steering_force_bonus_ratio = 0.0
	wind_reduction_ratio = 0.0
	release_drag_bonus_ratio = 0.0
	automatic_steering_enabled = false
	specialization_id = &""
	precise_recharge_enabled = false
	long_flight_restore_enabled = false
	front_sweep_enabled = false
	ground_core_enabled = false
	platform_core_enabled = false


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
		STEERING_FORCE_BONUS:
			steering_force_bonus_ratio += value
			return true
		WIND_REDUCTION:
			wind_reduction_ratio += value
			return true
		RELEASE_DRAG_BONUS:
			release_drag_bonus_ratio += value
			return true
	return false


func apply_flag(target_id: StringName) -> bool:
	if not _can_apply_flag(target_id):
		return false
	match target_id:
		AUTO_STEERING:
			automatic_steering_enabled = true
			return true
		PRECISE, SPEED, POWERFUL:
			specialization_id = target_id
			return true
		PRECISE_RECHARGE:
			precise_recharge_enabled = true
			return true
		SPEED_LONG_FLIGHT_RESTORE:
			long_flight_restore_enabled = true
			return true
		SPEED_FRONT_SWEEP:
			front_sweep_enabled = true
			return true
		POWERFUL_GROUND_CORE:
			ground_core_enabled = true
			return true
		POWERFUL_PLATFORM_CORE:
			platform_core_enabled = true
			return true
	return false


func has_precise_specialization() -> bool:
	return specialization_id == PRECISE


func has_speed_specialization() -> bool:
	return specialization_id == SPEED


func has_powerful_specialization() -> bool:
	return specialization_id == POWERFUL


func _can_apply_scalar(target_id: StringName, value: float) -> bool:
	if value <= 0.0:
		return false
	return target_id in [
		STEERING_FORCE_BONUS,
		WIND_REDUCTION,
		RELEASE_DRAG_BONUS,
	]


func _can_apply_flag(target_id: StringName) -> bool:
	match target_id:
		AUTO_STEERING:
			return not automatic_steering_enabled
		PRECISE, SPEED, POWERFUL:
			return specialization_id == &""
		PRECISE_RECHARGE:
			return has_precise_specialization() and not precise_recharge_enabled
		SPEED_LONG_FLIGHT_RESTORE:
			return has_speed_specialization() and not long_flight_restore_enabled
		SPEED_FRONT_SWEEP:
			return has_speed_specialization() and not front_sweep_enabled
		POWERFUL_GROUND_CORE:
			return has_powerful_specialization() and not ground_core_enabled
		POWERFUL_PLATFORM_CORE:
			return has_powerful_specialization() and not platform_core_enabled
	return false