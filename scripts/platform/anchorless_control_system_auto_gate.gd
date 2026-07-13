class_name AnchorlessControlSystemAutoGate
extends AnchorlessControlSystem


func can_apply_upgrade_effect(effect: UpgradeEffectDefinition) -> bool:
	if (
		effect != null
		and effect.target_id == AnchorlessControlUpgradeRuntime.AUTO_STEERING
		and not is_auto_steering_prerequisite_ready_for_tests()
	):
		return false
	return super.can_apply_upgrade_effect(effect)


func is_auto_steering_prerequisite_ready_for_tests() -> bool:
	return (
		upgrades.steering_force_bonus_ratio > 0.0
		and upgrades.wind_reduction_ratio > 0.0
		and upgrades.release_drag_bonus_ratio > 0.0
	)
