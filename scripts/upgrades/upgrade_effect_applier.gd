class_name UpgradeEffectApplier
extends RefCounted

var _buildables: BuildableInventory
var _runtime: UpgradeRuntime


func configure(
	buildables: BuildableInventory,
	runtime: UpgradeRuntime
) -> void:
	assert(buildables != null)
	assert(runtime != null)
	_buildables = buildables
	_runtime = runtime


func can_apply(definition: UpgradeDefinition) -> bool:
	if definition == null or not definition.is_valid():
		return false
	var effect: UpgradeEffectDefinition = definition.effect
	if effect == null or effect.effect_type == UpgradeEffectDefinition.EffectType.NONE:
		return true
	match effect.effect_type:
		UpgradeEffectDefinition.EffectType.UNLOCK_BUILDABLE:
			if _buildables == null:
				return false
			var current: int = _buildables.get_unlocked_count(effect.buildable_type_id)
			var maximum: int = _buildables.balance.get_max_count(effect.buildable_type_id)
			return current < maximum and effect.integer_value > 0
		UpgradeEffectDefinition.EffectType.UNLOCK_ROLE,
		UpgradeEffectDefinition.EffectType.DOMAIN_FLAG,
		UpgradeEffectDefinition.EffectType.DOMAIN_SCALAR:
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
			var after: int = _buildables.unlock(
				effect.buildable_type_id,
				effect.integer_value
			)
			return after > before
		UpgradeEffectDefinition.EffectType.UNLOCK_ROLE:
			_runtime.set_domain_flag(effect.target_id, true)
			return true
		UpgradeEffectDefinition.EffectType.DOMAIN_FLAG:
			_runtime.set_domain_flag(effect.target_id, true)
			return true
		UpgradeEffectDefinition.EffectType.DOMAIN_SCALAR:
			_runtime.add_domain_scalar(effect.target_id, effect.scalar_value)
			return true
	return false
