class_name AnchorlessUpgradeEffectApplier
extends UpgradeEffectApplier

var anchorless_system: AnchorlessControlSystem


func set_anchorless_system(value: AnchorlessControlSystem) -> void:
	anchorless_system = value


func can_apply(definition: UpgradeDefinition) -> bool:
	if _is_anchorless(definition):
		return anchorless_system != null and anchorless_system.can_apply_upgrade_effect(definition.effect)
	return super.can_apply(definition)


func apply_effect(definition: UpgradeDefinition) -> bool:
	if _is_anchorless(definition):
		return can_apply(definition) and anchorless_system.apply_upgrade_effect(definition.effect)
	return super.apply_effect(definition)


func _is_anchorless(definition: UpgradeDefinition) -> bool:
	if definition == null or not definition.is_valid() or definition.effect == null:
		return false
	return String(definition.effect.target_id).begins_with("anchorless_")
