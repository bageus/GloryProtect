class_name AnchorlessUpgradeEffectApplier
extends UpgradeEffectApplier

var _anchorless: AnchorlessControlSystem


func configure(
	buildables: BuildableInventory,
	runtime: UpgradeRuntime,
	crew: CrewManager = null,
	replacements: CrewReplacementController = null,
	turrets: TurretUpgradeSystem = null,
	medical: MedicalStationSystem = null,
	combat_anchors: CombatAnchorSystem = null,
	shield_core: ShieldCoreSystem = null,
	anchorless: AnchorlessControlSystem = null
) -> void:
	super.configure(
		buildables,
		runtime,
		crew,
		replacements,
		turrets,
		medical,
		combat_anchors,
		shield_core
	)
	_anchorless = anchorless


func can_apply(definition: UpgradeDefinition) -> bool:
	if _is_anchorless_definition(definition):
		return (
			_anchorless != null
			and _anchorless.can_apply_upgrade_effect(definition.effect)
		)
	return super.can_apply(definition)


func apply_effect(definition: UpgradeDefinition) -> bool:
	if _is_anchorless_definition(definition):
		return (
			can_apply(definition)
			and _anchorless.apply_upgrade_effect(definition.effect)
		)
	return super.apply_effect(definition)


func _is_anchorless_definition(definition: UpgradeDefinition) -> bool:
	if definition == null or not definition.is_valid():
		return false
	if definition.effect == null:
		return false
	return String(definition.effect.target_id).begins_with("anchorless_")
