class_name UpgradeEffectDefinition
extends Resource

enum EffectType {
	NONE,
	UNLOCK_BUILDABLE,
	UNLOCK_ROLE,
	DOMAIN_FLAG,
	DOMAIN_SCALAR,
	ADD_DEFENDER,
}

@export var effect_type: EffectType = EffectType.NONE
@export var target_id: StringName
@export var integer_value: int = 0
@export var scalar_value: float = 0.0
@export var buildable_type_id: int = -1


func is_valid() -> bool:
	match effect_type:
		EffectType.NONE:
			return true
		EffectType.UNLOCK_BUILDABLE:
			return buildable_type_id >= 0 and integer_value > 0
		EffectType.UNLOCK_ROLE, EffectType.DOMAIN_FLAG:
			return target_id != &""
		EffectType.DOMAIN_SCALAR:
			return target_id != &"" and not is_zero_approx(scalar_value)
		EffectType.ADD_DEFENDER:
			return integer_value > 0
	return false
