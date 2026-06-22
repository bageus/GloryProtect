class_name MedicAttackDefinition
extends Resource

enum AttackType {
	MELEE_SWORD,
}

@export var attack_type: AttackType = AttackType.MELEE_SWORD
@export_range(0, 10, 1) var damage_bonus: int = 1


func is_valid() -> bool:
	return attack_type == AttackType.MELEE_SWORD and damage_bonus >= 0
