class_name UpgradeEffectApplier
extends Node

@export_node_path("BuildableInventory") var buildable_inventory_path: NodePath
@export_node_path("UpgradeRuntime") var runtime_path: NodePath

@onready var _buildables: BuildableInventory = get_node(buildable_inventory_path)
@onready var _runtime: UpgradeRuntime = get_node(runtime_path)


func apply_effect(definition: UpgradeDefinition) -> bool:
	if definition == null or not definition.is_valid():
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
