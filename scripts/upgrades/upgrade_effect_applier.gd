class_name UpgradeEffectApplier
extends RefCounted

var _buildables: BuildableInventory
var _crew: CrewManager
var _replacements: CrewReplacementController
var _runtime: UpgradeRuntime
var _turrets: TurretUpgradeSystem
var _medical: MedicalStationSystem


func configure(
	buildables: BuildableInventory,
	runtime: UpgradeRuntime,
	crew: CrewManager = null,
	replacements: CrewReplacementController = null,
	turrets: TurretUpgradeSystem = null,
	medical: MedicalStationSystem = null
) -> void:
	assert(buildables != null)
	assert(runtime != null)
	_buildables = buildables
	_runtime = runtime
	_crew = crew
	_replacements = replacements
	_turrets = turrets
	_medical = medical


func can_apply(definition: UpgradeDefinition) -> bool:
	if definition == null or not definition.is_valid():
		return false
	var effect: UpgradeEffectDefinition = definition.effect
	if effect == null or effect.effect_type == UpgradeEffectDefinition.EffectType.NONE:
		return true
	match effect.effect_type:
		UpgradeEffectDefinition.EffectType.UNLOCK_BUILDABLE:
			var current: int = _buildables.get_unlocked_count(effect.buildable_type_id)
			var maximum: int = _buildables.balance.get_max_count(effect.buildable_type_id)
			return current < maximum and effect.integer_value > 0
		UpgradeEffectDefinition.EffectType.ADD_DEFENDER:
			return _crew != null and _crew.can_add_defender()
		UpgradeEffectDefinition.EffectType.CREW_MOVE_SPEED_MULTIPLIER:
			return _crew != null
		UpgradeEffectDefinition.EffectType.CREW_RESPAWN_MULTIPLIER:
			return _replacements != null
		UpgradeEffectDefinition.EffectType.UNLOCK_ROLE:
			return _runtime != null
		UpgradeEffectDefinition.EffectType.DOMAIN_FLAG,
		UpgradeEffectDefinition.EffectType.DOMAIN_SCALAR:
			if _is_turret_effect(effect):
				return _turrets != null and _turrets.can_apply_upgrade_effect(effect)
			if _is_melee_effect(effect):
				return _crew != null and _crew.get_melee_upgrades().can_apply_effect(effect)
			if _is_medic_effect(effect):
				return _medical != null and _medical.can_apply_upgrade_effect(effect)
			return _runtime != null
	return false


func apply_effect(definition: UpgradeDefinition) -> bool:
	if not can_apply(definition):
		return false
	var effect: UpgradeEffectDefinition = definition.effect
	if effect == null or effect.effect_type == UpgradeEffectDefinition.EffectType.NONE:
		return true
	match effect.effect_type:
		UpgradeEffectDefinition.EffectType.UNLOCK_BUILDABLE:
			var before: int = _buildables.get_unlocked_count(effect.buildable_type_id)
			var after: int = _buildables.unlock(effect.buildable_type_id, effect.integer_value)
			return after > before
		UpgradeEffectDefinition.EffectType.ADD_DEFENDER:
			var added: int = 0
			for _index: int in range(effect.integer_value):
				if _crew.add_defender() == null:
					break
				added += 1
			return added > 0
		UpgradeEffectDefinition.EffectType.CREW_MOVE_SPEED_MULTIPLIER:
			return _crew.multiply_movement_speed(effect.scalar_value)
		UpgradeEffectDefinition.EffectType.CREW_RESPAWN_MULTIPLIER:
			return _replacements.multiply_respawn_time(effect.scalar_value)
		UpgradeEffectDefinition.EffectType.UNLOCK_ROLE:
			_runtime.set_domain_flag(effect.target_id, true)
			return true
		UpgradeEffectDefinition.EffectType.DOMAIN_FLAG,
		UpgradeEffectDefinition.EffectType.DOMAIN_SCALAR:
			if _is_turret_effect(effect):
				return _turrets.apply_upgrade_effect(effect)
			if _is_melee_effect(effect):
				if effect.effect_type == UpgradeEffectDefinition.EffectType.DOMAIN_FLAG:
					return _crew.apply_melee_flag(effect.target_id)
				return _crew.apply_melee_scalar(effect.target_id, effect.scalar_value)
			if _is_medic_effect(effect):
				return _medical.apply_upgrade_effect(effect)
			if effect.effect_type == UpgradeEffectDefinition.EffectType.DOMAIN_FLAG:
				_runtime.set_domain_flag(effect.target_id, true)
				return true
			_runtime.add_domain_scalar(effect.target_id, effect.scalar_value)
			return true
	return false


func _is_turret_effect(effect: UpgradeEffectDefinition) -> bool:
	return String(effect.target_id).begins_with("turret_")


func _is_melee_effect(effect: UpgradeEffectDefinition) -> bool:
	return String(effect.target_id).begins_with("melee_")


func _is_medic_effect(effect: UpgradeEffectDefinition) -> bool:
	return String(effect.target_id).begins_with("medic_")
